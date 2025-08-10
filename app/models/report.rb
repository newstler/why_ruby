class Report < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :post, counter_cache: true

  # Enums
  enum :reason, {
    spam: 0,
    inappropriate: 1,
    off_topic: 2,
    harassment: 3,
    misinformation: 4,
    other: 5
  }

  # Validations
  validates :reason, presence: true
  validates :user_id, uniqueness: { scope: :post_id, message: "can only report post once" }
  validate :user_can_report

  # Callbacks
  after_create :check_post_threshold

  private

  def user_can_report
    unless user&.can_report?
      errors.add(:user, "must be a trusted user to report posts")
    end
  end

  def check_post_threshold
    post.auto_hide_if_needed!
  end
end
