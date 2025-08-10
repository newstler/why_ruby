class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: [:slugged, :history, :finders]
  
  # Associations
  has_many :posts, dependent: :nullify
  
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :slug, uniqueness: true, allow_blank: true
  validates :position, presence: true, uniqueness: true, numericality: { only_integer: true }
  
  # Scopes
  scope :ordered, -> { order(:position) }
  
  # Callbacks
  before_validation :set_position, on: :create
  
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
  

end 