class Comment < ApplicationRecord
  
  # Associations
  belongs_to :post
  belongs_to :user, counter_cache: :published_comments_count
  
  # Validations
  validates :body, presence: true
  
  # Scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Callbacks
  after_update :update_counter_caches
  
  private
  
  def update_counter_caches
    if saved_change_to_published?
      count = user.comments.published.count
      user.update_column(:published_comments_count, count) if user.present?
    end
  end
end 