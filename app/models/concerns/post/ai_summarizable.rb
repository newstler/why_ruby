# app/models/concerns/post/ai_summarizable.rb
module Post::AiSummarizable
  extend ActiveSupport::Concern

  def generate_summary!(force: false)
    return if summary.present? && !force

    text_to_summarize = prepare_text_for_summary
    return if text_to_summarize.blank? || text_to_summarize.length < 50

    chat = user.chats.create!(
      purpose: "summary",
      model: Model.find_by(model_id: Setting.get(:summary_model, default: Setting::DEFAULT_AI_MODEL))
    )

    prompt = "Output ONLY a single teaser sentence. No preamble. Maximum 200 characters. Hook the reader with the most intriguing aspect.\n\nTeaser:\n\n#{text_to_summarize}"

    response = chat.ask(prompt)
    raw_summary = response.content

    return unless raw_summary.present?

    cleaned = clean_ai_summary(raw_summary)
    update!(summary: cleaned)
    broadcast_summary_update
  rescue => e
    Rails.logger.error "Failed to generate summary for post #{id}: #{e.message}"
  end

  private

  def prepare_text_for_summary
    if link?
      text = fetch_external_content
      text = "Title: #{title}\nURL: #{url}" if text.blank?
    else
      text = ActionView::Base.full_sanitizer.sanitize(content)
    end

    text.to_s.truncate(6000)
  end

  def clean_ai_summary(raw)
    cleaned = raw.gsub(/^(Here is a |Here's a |Here are |Teaser: |The teaser: |One-sentence teaser: )/i, "")
    cleaned = cleaned.gsub(/^(This article |This page |This resource |Learn about |Discover |Explore )/i, "")
    cleaned = cleaned.gsub(/^["'](.+)["']$/, '\1')
    cleaned.strip
  end

  def broadcast_summary_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "post_#{id}",
      target: "post_#{id}_summary",
      partial: "posts/summary",
      locals: { post: self }
    )
  end
end
