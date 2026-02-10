require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    @project = projects(:rails_project)
    @hidden = projects(:hidden_project)
    @archived = projects(:archived_project)
  end

  test "validates name presence" do
    @project.name = nil
    assert_not @project.valid?
    assert @project.errors[:name].any?
  end

  test "validates github_url presence" do
    @project.github_url = nil
    assert_not @project.valid?
    assert @project.errors[:github_url].any?
  end

  test "validates github_url uniqueness scoped to user" do
    duplicate = Project.new(
      user: @project.user,
      name: "duplicate",
      github_url: @project.github_url
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:github_url].any?
  end

  test "allows same github_url for different users" do
    other_user = users(:admin_user)
    project = Project.new(
      user: other_user,
      name: "same-url",
      github_url: @project.github_url
    )
    assert project.valid?
  end

  test "visible scope excludes hidden and archived" do
    visible = Project.visible
    assert_includes visible, @project
    assert_not_includes visible, @hidden
    assert_not_includes visible, @archived
  end

  test "hidden scope returns only hidden projects" do
    hidden = Project.hidden
    assert_includes hidden, @hidden
    assert_not_includes hidden, @project
  end

  test "archived scope returns only archived projects" do
    archived = Project.archived
    assert_includes archived, @archived
    assert_not_includes archived, @project
  end

  test "active scope excludes archived" do
    active = Project.active
    assert_includes active, @project
    assert_includes active, @hidden
    assert_not_includes active, @archived
  end

  test "stars_gained returns difference between two most recent snapshots" do
    gained = @project.stars_gained
    assert_equal 10, gained
  end

  test "stars_gained returns 0 with only one snapshot" do
    gained = @hidden.stars_gained
    assert_equal 0, gained
  end

  test "stars_gained returns 0 when stars decreased" do
    project = projects(:admin_project)
    project.star_snapshots.find_by(recorded_on: Date.current).update!(stars: 470)
    assert_equal 0, project.stars_gained
  end

  test "record_snapshot creates new snapshot for today" do
    project = projects(:archived_project)
    project.update!(stars: 15)

    snapshot = project.record_snapshot!

    assert_equal Date.current, snapshot.recorded_on
    assert_equal 15, snapshot.stars
  end

  test "record_snapshot does not update existing snapshot for today by default" do
    original_stars = @project.star_snapshots.find_by(recorded_on: Date.current).stars
    @project.update!(stars: 200)

    @project.record_snapshot!

    assert_equal original_stars, @project.star_snapshots.find_by(recorded_on: Date.current).stars
  end

  test "record_snapshot with force updates existing snapshot for today" do
    initial_count = @project.star_snapshots.count
    @project.update!(stars: 200)

    @project.record_snapshot!(force: true)

    assert_equal initial_count, @project.star_snapshots.count
    assert_equal 200, @project.star_snapshots.find_by(recorded_on: Date.current).stars
  end

  test "belongs to user" do
    assert_equal users(:user_with_testimonial), @project.user
  end

  test "has many star_snapshots" do
    assert @project.star_snapshots.count >= 2
  end
end
