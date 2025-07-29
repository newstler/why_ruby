class Tag < ApplicationRecord
  # Soft deletion
  default_scope { where(archived: false) }
  
  # Associations
  has_and_belongs_to_many :contents
  
  # Validations
  validates :name, presence: true, uniqueness: true
  
  # Scopes
  scope :active, -> { where(archived: false) }
  scope :with_published_contents, -> {
    joins(:contents).where(contents: { published: true, archived: false }).distinct
  }
  
  # Instance methods
  def published_contents_count
    contents.published.count
  end
end 