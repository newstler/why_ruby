class StarSnapshot < ApplicationRecord
  belongs_to :project

  validates :stars, numericality: { greater_than_or_equal_to: 0 }
  validates :recorded_on, presence: true, uniqueness: { scope: :project_id }

  scope :chronological, -> { order(recorded_on: :asc) }
  scope :recent, -> { order(recorded_on: :desc) }
end
