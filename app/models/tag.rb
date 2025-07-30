class Tag < ApplicationRecord
  # Soft deletion
  default_scope { where(archived: false) }
  
  # Associations
  has_and_belongs_to_many :posts
  
  # Validations
  validates :name, presence: true, uniqueness: true
  
  # Scopes
  scope :active, -> { where(archived: false) }
  scope :with_published_posts, -> {
    joins(:posts).where(posts: { published: true, archived: false }).distinct
  }
  
  # Instance methods
  def published_posts_count
    posts.published.count
  end
end 