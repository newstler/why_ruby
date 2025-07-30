class GenerateSummaryJob < ApplicationJob
  queue_as :default
  
  def perform(post)
    return unless post.published? && post.summary.blank?
    
    # Initialize OpenAI client
    client = OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :api_key))
    
    # Prepare the text for summarization
    text_to_summarize = if post.article?
      post.content
    else
      "#{post.title} - #{post.url}"
    end
    
    # Truncate to reasonable length for API
    text_to_summarize = text_to_summarize.truncate(4000)
    
    begin
      response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            {
              role: "system",
              content: "You are a helpful assistant that creates concise summaries of Ruby programming content. Keep summaries under 200 words."
            },
            {
              role: "user",
              content: "Please summarize this content: #{text_to_summarize}"
            }
          ],
          temperature: 0.7,
          max_tokens: 200
        }
      )
      
      summary = response.dig("choices", 0, "message", "content")
      post.update!(summary: summary) if summary.present?
    rescue => e
      Rails.logger.error "Failed to generate summary for post #{post.id}: #{e.message}"
    end
  end
end 