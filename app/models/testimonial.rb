class Testimonial < ApplicationRecord
  include Testimonial::AiGeneratable
  include Testimonial::AiTranslatable
  include Testimonial::AiValidatable
  include Testimonial::Screenable

  belongs_to :user

  # System writes (translation, admin backfills) set this so a longer English
  # translation is never rejected — and never trimmed — by the authoring cap.
  attr_accessor :system_generated

  # The 140-320 range is an authoring guide for the submission form. System
  # writes (translation, admin rewrites) are exempt: a faithful translation may
  # land either side of the range and must never be padded or trimmed to fit.
  validates :quote, length: { minimum: 140, maximum: 320 }, allow_blank: true, unless: :system_generated
  validates :user_id, uniqueness: true

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(Arel.sql("position ASC NULLS LAST, created_at DESC")) }

  after_save :process_quote_change, if: -> { saved_change_to_quote? && !system_generated }

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
      GenerateTestimonialJob.perform_later(self)
    end
  end

  def broadcast_testimonial_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "testimonial_#{id}",
      target: "testimonial_section",
      partial: "testimonials/section",
      locals: { testimonial: self, user: user }
    )
  end
end
