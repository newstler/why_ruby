class Tag < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: [ :slugged, :history, :finders ]

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

  # Ensure old slug is saved to history when slug changes
  before_save :create_slug_history, if: :will_save_change_to_slug?

  def create_slug_history
    if slug_was.present? && slug_was != slug
      FriendlyId::Slug.create!(
        slug: slug_was,
        sluggable_id: id,
        sluggable_type: self.class.name
      ) rescue nil
    end
  end
end
