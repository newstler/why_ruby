class Report < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :content, counter_cache: true
  
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
  validates :user_id, uniqueness: { scope: :content_id, message: "can only report content once" }
  validate :user_can_report
  
  # Callbacks
  after_create :check_content_threshold
  
  private
  
  def user_can_report
    unless user&.can_report?
      errors.add(:user, "must be a trusted user to report content")
    end
  end
  
  def check_content_threshold
    content.auto_hide_if_needed!
  end
end 