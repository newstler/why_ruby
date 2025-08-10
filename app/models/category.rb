class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: [:slugged, :history]
  
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
  
  private
  
  def set_position
    self.position ||= (Category.unscoped.maximum(:position) || 0) + 1
  end
  

end 