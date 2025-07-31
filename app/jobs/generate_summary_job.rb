class GenerateSummaryJob < ApplicationJob
  queue_as :default
  
  def perform(post)
    return unless post.published? && post.summary.blank?
    
    # Prepare the text for summarization
    text_to_summarize = prepare_text(post)
    
    # Try different AI providers
    summary = nil
    error = nil
    
    # Try Anthropic first if available
    if anthropic_configured?
      summary = generate_with_anthropic(text_to_summarize)
    end
    
    # Fall back to OpenAI if Anthropic fails or is not configured
    if summary.blank? && openai_configured?
      summary = generate_with_openai(text_to_summarize)
    end
    
    if summary.present?
      post.update!(summary: summary)
      broadcast_update(post)
    else
      Rails.logger.error "Failed to generate summary for post #{post.id}: No AI service available or all failed"
    end
  end
  
  private
  
  def prepare_text(post)
    text = if post.article?
      post.content
    else
      "#{post.title} - #{post.url}"
    end
    
    # Remove markdown formatting for cleaner summaries
    text = ActionView::Base.full_sanitizer.sanitize(text)
    text.truncate(4000)
  end
  
  def anthropic_configured?
    Rails.application.credentials.dig(:anthropic, :access_token).present?
  end
  
  def openai_configured?
    Rails.application.credentials.dig(:openai, :access_token).present?
  end
  
  def generate_with_anthropic(text)
    client = Anthropic::Client.new(
      access_token: Rails.application.credentials.dig(:anthropic, :access_token)
    )
    
    begin
      response = client.messages(
        parameters: {
          model: "claude-3-haiku-20240307",
          max_tokens: 150,
          temperature: 0.7,
          system: "You are a technical writer creating concise summaries of Ruby programming content. Write a direct, informative summary in 2-3 sentences that captures the key technical points. Use markdown formatting where appropriate. Do not start with phrases like 'This article' or 'Here's a summary'.",
          messages: [
            {
              role: "user",
              content: "Summarize this Ruby programming content in 2-3 sentences:\n\n#{text}"
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
  
  def generate_with_openai(text)
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :access_token)
    )
    
    begin
      response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            {
              role: "system",
              content: "You are a technical writer creating concise summaries of Ruby programming content. Write a direct, informative summary in 2-3 sentences that captures the key technical points. Use markdown formatting where appropriate. Do not start with phrases like 'This article' or 'Here's a summary'."
            },
            {
              role: "user",
              content: "Summarize this Ruby programming content in 2-3 sentences:\n\n#{text}"
            }
          ],
          temperature: 0.7,
          max_tokens: 150
        }
      )
      
      response.dig("choices", 0, "message", "content")
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      nil
    end
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