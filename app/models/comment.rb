class Comment < ApplicationRecord
  
  # Associations
  belongs_to :post
  belongs_to :user
  
  # Validations
  validates :body, presence: true
  
  # Scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Callbacks
  after_create :update_user_counter_caches
  after_update :update_user_counter_caches
  after_destroy :update_user_counter_caches
  
  private
  
  def update_user_counter_caches
    # Update the counter if:
    # 1. A new published comment was created
    # 2. The published status changed
    # 3. A comment was destroyed
    if destroyed? || (persisted? && (saved_change_to_published? || (published? && previously_new_record?)))
      count = user.comments.published.count
      user.update_column(:published_comments_count, count) if user.present?
    end
  end
end 