class GenerateSummaryJob < ApplicationJob
  queue_as :default
  
  def perform(post)
    return unless post.published? && post.summary.blank?
    
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
      post.update!(summary: summary)
      broadcast_update(post)
    else
      Rails.logger.error "Failed to generate summary for post #{post.id}: No AI service available or all failed"
    end
  end
  
  private
  
  def prepare_text_with_context(post)
    if post.article?
      # For articles, use the actual content
      text = post.content
      # Remove markdown formatting for cleaner summaries
      text = ActionView::Base.full_sanitizer.sanitize(text)
      context = {
        type: 'article',
        title: post.title,
        has_code: post.content.include?('```')
      }
    else
      # For external links, fetch the actual content
      text = fetch_external_content(post.url)
      
      # If fetching failed, try to at least use title
      if text.blank?
        text = "Title: #{post.title}\nURL: #{post.url}"
      end
      
      context = {
        type: 'external_link',
        title: post.title,
        url: post.url,
        domain: (URI.parse(post.url).host rescue nil)
      }
    end
    
    # Truncate to reasonable length
    text = text.to_s.truncate(6000)
    
    [text, context]
  end
  
  def fetch_external_content(url)
    begin
      Rails.logger.info "Fetching content from: #{url}"
      
      page = MetaInspector.new(url, 
        connection_timeout: 5, 
        read_timeout: 5,
        retries: 1,
        allow_redirections: :safe
      )
      
      # Try to get the main content
      content_parts = []
      
      # Add title
      content_parts << "Title: #{page.best_title}" if page.best_title.present?
      
      # Add description
      content_parts << "Description: #{page.best_description}" if page.best_description.present?
      
      # Get the main text content
      if page.parsed.present?
        # Try to extract main content, removing navigation, ads, etc.
        main_content = extract_main_content(page.parsed)
        content_parts << main_content if main_content.present?
      end
      
      # Fallback to meta description and raw text if needed
      if content_parts.length <= 2
        raw_text = page.parsed.css('body').text.squish rescue nil
        content_parts << raw_text if raw_text.present?
      end
      
      content_parts.join("\n\n")
    rescue => e
      Rails.logger.error "Failed to fetch external content from #{url}: #{e.message}"
      nil
    end
  end
  
  def extract_main_content(parsed_doc)
    # Try common content selectors
    content_selectors = [
      'main', 'article', '[role="main"]', '.content', '#content',
      '.post-content', '.entry-content', '.article-body'
    ]
    
    content_selectors.each do |selector|
      element = parsed_doc.at_css(selector)
      if element
        text = element.text.squish
        return text if text.length > 100
      end
    end
    
    # If no main content found, try paragraphs
    paragraphs = parsed_doc.css('p').map(&:text).reject(&:blank?)
    return paragraphs.join(' ') if paragraphs.any?
    
    nil
  end
  
  def anthropic_configured?
    Rails.application.credentials.dig(:anthropic, :access_token).present?
  end
  
  def openai_configured?
    Rails.application.credentials.dig(:openai, :access_token).present?
  end
  
  def generate_with_anthropic(text, context)
    client = Anthropic::Client.new(
      access_token: Rails.application.credentials.dig(:anthropic, :access_token)
    )
    
    system_prompt = build_system_prompt(context)
    user_prompt = build_user_prompt(text, context)
    
    begin
      response = client.messages(
        parameters: {
          model: "claude-3-haiku-20240307",
          max_tokens: 250,
          temperature: 0.5,
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
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :access_token)
    )
    
    system_prompt = build_system_prompt(context)
    user_prompt = build_user_prompt(text, context)
    
    begin
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
          temperature: 0.5,
          max_tokens: 250
        }
      )
      
      response.dig("choices", 0, "message", "content")
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      nil
    end
  end
  
  def build_system_prompt(context)
    "CRITICAL: Output ONLY 2-3 content sentences. NO introductions like 'Here are' or 'The key insights'. Start directly with a fact. Focus on surprising or advanced points that distinguish THIS specific content. Minimal **bold** for technical terms."
  end
  
  def build_user_prompt(text, context)
    "Output 2-3 sentences of unique facts from this content. Start directly with the content:\n\n#{text}"
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