require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_with_testimonial)
  end

  test "record_newsletter_opened! adds version" do
    assert_equal [], @user.newsletters_opened

    @user.record_newsletter_opened!(1)
    @user.reload

    assert_includes @user.newsletters_opened, 1
  end

  test "record_newsletter_opened! is idempotent" do
    @user.record_newsletter_opened!(1)
    @user.record_newsletter_opened!(1)
    @user.reload

    assert_equal [ 1 ], @user.newsletters_opened
  end

  test "opened_newsletter? returns true after recording" do
    refute @user.opened_newsletter?(1)

    @user.record_newsletter_opened!(1)

    assert @user.opened_newsletter?(1)
  end

  test "newsletter_open_token generates verifiable token" do
    token = @user.newsletter_open_token(1)
    data = Rails.application.message_verifier("newsletter_open").verify(token)

    assert_equal @user.id, data["user_id"]
    assert_equal 1, data["version"]
  end

  test "visible_ruby_repositories returns visible projects" do
    repos = @user.visible_ruby_repositories
    assert_includes repos, projects(:rails_project)
    assert_not_includes repos, projects(:hidden_project)
    assert_not_includes repos, projects(:archived_project)
  end

  test "hidden_ruby_repositories returns hidden active projects" do
    repos = @user.hidden_ruby_repositories
    assert_includes repos, projects(:hidden_project)
    assert_not_includes repos, projects(:rails_project)
    assert_not_includes repos, projects(:archived_project)
  end

  test "hide_repository! hides a visible project" do
    project = projects(:rails_project)
    @user.hide_repository!(project.github_url)
    project.reload
    assert project.hidden?
  end

  test "unhide_repository! unhides a hidden project" do
    project = projects(:hidden_project)
    @user.unhide_repository!(project.github_url)
    project.reload
    assert_not project.hidden?
  end

  test "total_github_stars returns github_stars_sum" do
    @user.update!(github_stars_sum: 999)
    assert_equal 999, @user.total_github_stars
  end

  test "recalculate_visible_stats! computes from visible projects" do
    @user.recalculate_visible_stats!
    @user.reload
    assert_equal 1, @user.github_repos_count
    assert_equal 150, @user.github_stars_sum
  end

  # -------------------------------------------------------------------------
  # Trusted user threshold
  # -------------------------------------------------------------------------

  test "user is trusted with 3+ published posts and 10+ published comments" do
    @user.update_columns(published_posts_count: 3, published_comments_count: 10)
    assert @user.trusted?
    assert User.trusted.exists?(@user.id)
  end

  test "user is not trusted with fewer than 3 published posts" do
    @user.update_columns(published_posts_count: 2, published_comments_count: 10)
    assert_not @user.trusted?
    assert_not User.trusted.exists?(@user.id)
  end

  test "user is not trusted with fewer than 10 published comments" do
    @user.update_columns(published_posts_count: 3, published_comments_count: 9)
    assert_not @user.trusted?
    assert_not User.trusted.exists?(@user.id)
  end
end
