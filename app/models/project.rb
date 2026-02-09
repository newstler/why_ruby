class Project < ApplicationRecord
  belongs_to :user
  has_many :star_snapshots, dependent: :destroy

  validates :name, presence: true
  validates :github_url, presence: true, uniqueness: { scope: :user_id }

  scope :visible, -> { where(hidden: false, archived: false) }
  scope :hidden, -> { where(hidden: true) }
  scope :archived, -> { where(archived: true) }
  scope :active, -> { where(archived: false) }
  scope :by_stars, -> { order(stars: :desc) }
  scope :by_pushed_at, -> { order(Arel.sql("CASE WHEN pushed_at IS NULL THEN 1 ELSE 0 END, pushed_at DESC")) }

  def stars_gained
    snapshots = star_snapshots.recent.limit(2).pluck(:stars)
    return 0 if snapshots.size < 2
    [ snapshots.first - snapshots.last, 0 ].max
  end

  def record_snapshot!
    snapshot = star_snapshots.find_or_initialize_by(recorded_on: Date.current)
    snapshot.update!(stars: stars)
    snapshot
  end
end
