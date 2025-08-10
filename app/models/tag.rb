class Tag < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: [:slugged, :history]
  
  # Associations
  has_and_belongs_to_many :posts
  
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :slug, uniqueness: true, allow_blank: true
  
  # Scopes
  scope :with_published_posts, -> {
    joins(:posts).where(posts: { published: true }).distinct
  }
  
  # Instance methods
  def published_posts_count
    posts.published.count
  end
  
  def should_generate_new_friendly_id?
    name_changed? || super
  end
end 