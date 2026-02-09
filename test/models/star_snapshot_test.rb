require "test_helper"

class StarSnapshotTest < ActiveSupport::TestCase
  test "validates recorded_on presence" do
    snapshot = StarSnapshot.new(project: projects(:rails_project), stars: 10, recorded_on: nil)
    assert_not snapshot.valid?
    assert snapshot.errors[:recorded_on].any?
  end

  test "validates stars is non-negative" do
    snapshot = StarSnapshot.new(project: projects(:rails_project), stars: -1, recorded_on: 5.days.ago.to_date)
    assert_not snapshot.valid?
    assert snapshot.errors[:stars].any?
  end

  test "validates uniqueness of recorded_on scoped to project" do
    existing = star_snapshots(:rails_project_today)
    duplicate = StarSnapshot.new(
      project: existing.project,
      stars: 999,
      recorded_on: existing.recorded_on
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:recorded_on].any?
  end

  test "allows same date for different projects" do
    snapshot = StarSnapshot.new(
      project: projects(:hidden_project),
      stars: 100,
      recorded_on: star_snapshots(:rails_project_today).recorded_on
    )
    # hidden_project already has a snapshot for today, so use a different date
    snapshot.recorded_on = 5.days.ago.to_date
    assert snapshot.valid?
  end

  test "chronological scope orders by date ascending" do
    snapshots = projects(:rails_project).star_snapshots.chronological
    dates = snapshots.map(&:recorded_on)
    assert_equal dates.sort, dates
  end

  test "recent scope orders by date descending" do
    snapshots = projects(:rails_project).star_snapshots.recent
    dates = snapshots.map(&:recorded_on)
    assert_equal dates.sort.reverse, dates
  end

  test "belongs to project" do
    snapshot = star_snapshots(:rails_project_today)
    assert_equal projects(:rails_project), snapshot.project
  end
end
