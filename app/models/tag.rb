class Tag < ApplicationRecord
  
  # Associations
  has_and_belongs_to_many :posts
  
  # Validations
  validates :name, presence: true, uniqueness: true
  
  # Scopes
  scope :with_published_posts, -> {
    joins(:posts).where(posts: { published: true }).distinct
  }
  
  # Instance methods
  def published_posts_count
    posts.published.count
  end
end 