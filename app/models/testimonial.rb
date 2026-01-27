class Testimonial < ApplicationRecord
  belongs_to :user

  validates :quote, presence: true, length: { minimum: 140, maximum: 320 }
  validates :user_id, uniqueness: true
  validates :heading, uniqueness: true, allow_nil: true

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(Arel.sql("position ASC NULLS LAST, created_at DESC")) }

  after_save :enqueue_ai_processing, if: -> { saved_change_to_quote? }

  private

  def enqueue_ai_processing
    update_columns(ai_attempts: 0, published: false, ai_feedback: nil, reject_reason: nil)
    GenerateTestimonialFieldsJob.perform_later(self)
  end
end
