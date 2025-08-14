class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: [ :slugged, :history, :finders ]

  # Associations
  has_many :posts, dependent: :nullify

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :slug, uniqueness: true, allow_blank: true
  validates :position, presence: true, uniqueness: true, numericality: { only_integer: true }
  validate :only_one_success_story_category

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :with_posts, -> { joins(:posts).distinct }
  scope :regular, -> { where(is_success_story: false) }
  scope :success_story, -> { where(is_success_story: true).first }

  # Callbacks
  before_validation :set_position, on: :create

  # Class methods
  def self.success_story_category
    find_by(is_success_story: true)
  end

  # Instance methods
  def should_generate_new_friendly_id?
    name_changed? || super
  end

  # Ensure old slug is saved to history when slug changes
  before_save :create_slug_history, if: :will_save_change_to_slug?

  def create_slug_history
    if slug_was.present? && slug_was != slug
      # Save the old slug to history
      FriendlyId::Slug.create!(
        slug: slug_was,
        sluggable_id: id,
        sluggable_type: self.class.name
      ) rescue nil # Ignore if already exists
    end
  end

  private

  def set_position
    self.position ||= (Category.unscoped.maximum(:position) || 0) + 1
  end

  def only_one_success_story_category
    return unless is_success_story?

    existing = Category.where(is_success_story: true)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:is_success_story, "can only be set for one category")
    end
  end
end
