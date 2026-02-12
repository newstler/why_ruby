class Testimonial < ApplicationRecord
  belongs_to :user

  validates :quote, length: { minimum: 140, maximum: 320 }, allow_blank: true
  validates :user_id, uniqueness: true

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(Arel.sql("position ASC NULLS LAST, created_at DESC")) }

  after_save :process_quote_change, if: -> { saved_change_to_quote? }

  private

  def process_quote_change
    if quote.blank?
      # Empty quote - just save as unpublished with feedback, no AI processing
      update_columns(
        ai_attempts: 0,
        published: false,
        ai_feedback: "",
        reject_reason: nil,
        heading: nil,
        subheading: nil,
        body_text: nil
      )
    else
      # Non-empty quote - process with AI
      update_columns(ai_attempts: 0, published: false, ai_feedback: nil, reject_reason: nil)
      GenerateTestimonialFieldsJob.perform_later(self)
    end
  end
end
