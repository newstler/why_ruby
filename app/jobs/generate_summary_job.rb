class GenerateSummaryJob < ApplicationJob
  queue_as :default

  def perform(post, force: false)
    # Skip if summary exists and we're not forcing regeneration
    return if post.summary.present? && !force

    # Prepare the text and context for summarization
    text_to_summarize, context = prepare_text_with_context(post)

    # Skip if we couldn't get meaningful text
    if text_to_summarize.blank? || text_to_summarize.length < 50
      Rails.logger.warn "Insufficient content for summary generation for post #{post.id}"
      return
    end

    # Try different AI providers
    summary = nil
    error = nil

    # Try Anthropic first if available
    if anthropic_configured?
      summary = generate_with_anthropic(text_to_summarize, context)
    end

    # Fall back to OpenAI if Anthropic fails or is not configured
    if summary.blank? && openai_configured?
      summary = generate_with_openai(text_to_summarize, context)
    end

    if summary.present?
      # Clean up any meta-language and enforce length
      summary = clean_summary(summary)
      post.update!(summary: summary)
      broadcast_update(post)
    else
      Rails.logger.error "Failed to generate summary for post #{post.id}: No AI service available or all failed"
    end
  end

  private

  def prepare_text_with_context(post)
    if post.link?
      # For external links, fetch the actual content
      text = post.fetch_external_content

      # If fetching failed, try to at least use title
      if text.blank?
        text = "Title: #{post.title}\nURL: #{post.url}"
      end

      context = {
        type: "external_link",
        title: post.title,
        url: post.url,
        domain: (URI.parse(post.url).host rescue nil)
      }
    else
      # For articles and success stories, use the actual content
      text = post.content
      # Remove markdown formatting for cleaner summaries
      text = ActionView::Base.full_sanitizer.sanitize(text)
      context = {
        type: post.post_type,
        title: post.title,
        has_code: post.content.include?("```")
      }
    end

    # Truncate to reasonable length
    text = text.to_s.truncate(6000)

    [ text, context ]
  end

  def anthropic_configured?
    Rails.application.credentials.dig(:anthropic, :api_key).present? ||
      Rails.application.credentials.dig(:anthropic, :access_token).present?
  end

  def openai_configured?
    Rails.application.credentials.dig(:openai, :api_key).present? ||
      Rails.application.credentials.dig(:openai, :access_token).present?
  end

  def generate_with_anthropic(text, context)
    api_key = Rails.application.credentials.dig(:anthropic, :api_key).presence ||
      Rails.application.credentials.dig(:anthropic, :access_token)

    begin
      client = Anthropic::Client.new(
        api_key: api_key
      )

      system_prompt = build_system_prompt(context)
      user_prompt = build_user_prompt(text, context)

      response = client.messages(
        parameters: {
          model: "claude-3-haiku-20240307",
          max_tokens: 50,
          temperature: 0.3,
          system: system_prompt,
          messages: [
            {
              role: "user",
              content: user_prompt
            }
          ]
        }
      )

      response.dig("content", 0, "text")
    rescue => e
      Rails.logger.error "Anthropic API error: #{e.message}"
      nil
    end
  end

  def generate_with_openai(text, context)
    token = Rails.application.credentials.dig(:openai, :api_key).presence ||
      Rails.application.credentials.dig(:openai, :access_token)

    begin
      client = OpenAI::Client.new(
        access_token: token
      )

      system_prompt = build_system_prompt(context)
      user_prompt = build_user_prompt(text, context)

      response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            {
              role: "system",
              content: system_prompt
            },
            {
              role: "user",
              content: user_prompt
            }
          ],
          temperature: 0.3,
          max_tokens: 50
        }
      )

      response.dig("choices", 0, "message", "content")
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      nil
    end
  end

  def build_system_prompt(context)
    "Output ONLY a single teaser sentence. No preamble. Maximum 200 characters. Hook the reader with the most intriguing aspect."
  end

  def build_user_prompt(text, context)
    "Teaser:\n\n#{text}"
  end

  def clean_summary(summary)
    # Remove common meta-language prefixes
    cleaned = summary.gsub(/^(Here is a |Here's a |Here are |Teaser: |The teaser: |One-sentence teaser: )/i, "")
    cleaned = cleaned.gsub(/^(This article |This page |This resource |Learn about |Discover |Explore )/i, "")

    # Remove quotes if the entire summary is quoted
    cleaned = cleaned.gsub(/^["'](.+)["']$/, '\1')

    cleaned.strip
  end

  def broadcast_update(post)
    # Broadcast the summary update via Turbo Streams
    Turbo::StreamsChannel.broadcast_replace_to(
      "post_#{post.id}",
      target: "post_#{post.id}_summary",
      partial: "posts/summary",
      locals: { post: post }
    )
  end
end
