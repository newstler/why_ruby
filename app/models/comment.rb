class Comment < ApplicationRecord
  # Soft deletion
  default_scope { where(archived: false) }
  
  # Associations
  belongs_to :content
  belongs_to :user, counter_cache: :published_comments_count
  
  # Validations
  validates :body, presence: true
  
  # Scopes
  scope :published, -> { where(published: true, archived: false) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Callbacks
  after_update :update_counter_caches
  
  private
  
  def update_counter_caches
    if saved_change_to_published? || saved_change_to_archived?
      count = user.comments.published.count
      user.update_column(:published_comments_count, count)
    end
  end
end 