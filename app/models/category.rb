class Category < ApplicationRecord
  # Soft deletion
  default_scope { where(archived: false) }
  
  # Associations
  has_many :posts, dependent: :nullify
  
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :position, presence: true, uniqueness: true, numericality: { only_integer: true }
  
  # Scopes
  scope :ordered, -> { order(:position) }
  scope :active, -> { where(archived: false) }
  
  # Callbacks
  before_validation :set_position, on: :create
  
  private
  
  def set_position
    self.position ||= (Category.unscoped.maximum(:position) || 0) + 1
  end
  

end 