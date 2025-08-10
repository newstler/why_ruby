require "test_helper"

class CounterCacheTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  # Skip fixtures for this test
  def setup_fixtures
    # Do nothing - we create our own test data
  end

  def teardown_fixtures
    # Do nothing - we handle our own cleanup
  end

  setup do
    @user = User.create!(
      username: "test_user_#{SecureRandom.hex(4)}",
      email: "test_#{SecureRandom.hex(4)}@example.com",
      github_id: SecureRandom.random_number(1_000_000),
      name: "Test User"
    )

    @category = Category.create!(
      name: "Test Category #{SecureRandom.hex(4)}",
      position: SecureRandom.random_number(1000) + 1000
    )
  end

  teardown do
    @user.destroy if @user&.persisted?
    @category.destroy if @category&.persisted?
  end

  test "published_posts_count increments when creating a published post" do
    initial_count = @user.published_posts_count

    @user.posts.create!(
      title: "Test Post",
      content: "Test content",
      category: @category,
      published: true
    )

    @user.reload
    assert_equal initial_count + 1, @user.published_posts_count
  end

  test "published_posts_count does not increment when creating an unpublished post" do
    initial_count = @user.published_posts_count

    @user.posts.create!(
      title: "Unpublished Post",
      content: "Test content",
      category: @category,
      published: false
    )

    @user.reload
    assert_equal initial_count, @user.published_posts_count
  end

  test "published_posts_count increments when publishing an unpublished post" do
    post = @user.posts.create!(
      title: "Initially Unpublished",
      content: "Test content",
      category: @category,
      published: false
    )

    @user.reload
    initial_count = @user.published_posts_count

    post.update!(published: true)

    @user.reload
    assert_equal initial_count + 1, @user.published_posts_count
  end

  test "published_posts_count decrements when unpublishing a published post" do
    post = @user.posts.create!(
      title: "Initially Published",
      content: "Test content",
      category: @category,
      published: true
    )

    @user.reload
    initial_count = @user.published_posts_count

    post.update!(published: false)

    @user.reload
    assert_equal initial_count - 1, @user.published_posts_count
  end

  test "published_posts_count decrements when destroying a published post" do
    post = @user.posts.create!(
      title: "To Be Destroyed",
      content: "Test content",
      category: @category,
      published: true
    )

    @user.reload
    initial_count = @user.published_posts_count

    post.destroy

    @user.reload
    assert_equal initial_count - 1, @user.published_posts_count
  end

  test "published_comments_count increments when creating a published comment" do
    post = @user.posts.create!(
      title: "Test Post",
      content: "Test content",
      category: @category,
      published: true
    )

    initial_count = @user.published_comments_count

    @user.comments.create!(
      body: "Test comment",
      post: post,
      published: true
    )

    @user.reload
    assert_equal initial_count + 1, @user.published_comments_count
  end

  test "published_comments_count does not increment when creating an unpublished comment" do
    post = @user.posts.create!(
      title: "Test Post",
      content: "Test content",
      category: @category,
      published: true
    )

    initial_count = @user.published_comments_count

    @user.comments.create!(
      body: "Unpublished comment",
      post: post,
      published: false
    )

    @user.reload
    assert_equal initial_count, @user.published_comments_count
  end

  test "published_comments_count increments when publishing an unpublished comment" do
    post = @user.posts.create!(
      title: "Test Post",
      content: "Test content",
      category: @category,
      published: true
    )

    comment = @user.comments.create!(
      body: "Initially unpublished",
      post: post,
      published: false
    )

    @user.reload
    initial_count = @user.published_comments_count

    comment.update!(published: true)

    @user.reload
    assert_equal initial_count + 1, @user.published_comments_count
  end

  test "published_comments_count decrements when unpublishing a published comment" do
    post = @user.posts.create!(
      title: "Test Post",
      content: "Test content",
      category: @category,
      published: true
    )

    comment = @user.comments.create!(
      body: "Initially published",
      post: post,
      published: true
    )

    @user.reload
    initial_count = @user.published_comments_count

    comment.update!(published: false)

    @user.reload
    assert_equal initial_count - 1, @user.published_comments_count
  end

  test "published_comments_count decrements when destroying a published comment" do
    post = @user.posts.create!(
      title: "Test Post",
      content: "Test content",
      category: @category,
      published: true
    )

    comment = @user.comments.create!(
      body: "To be destroyed",
      post: post,
      published: true
    )

    @user.reload
    initial_count = @user.published_comments_count

    comment.destroy

    @user.reload
    assert_equal initial_count - 1, @user.published_comments_count
  end

  test "reports_count increments when creating a report" do
    # Create a trusted reporter user
    reporter = User.create!(
      username: "reporter_#{SecureRandom.hex(4)}",
      email: "reporter_#{SecureRandom.hex(4)}@example.com",
      github_id: SecureRandom.random_number(1_000_000),
      name: "Reporter User",
      published_posts_count: 5,
      published_comments_count: 15
    )

    post = @user.posts.create!(
      title: "Test Post",
      content: "Test content",
      category: @category,
      published: true
    )

    initial_count = post.reports_count

    reporter.reports.create!(
      post: post,
      reason: :spam
    )

    post.reload
    assert_equal initial_count + 1, post.reports_count

    reporter.destroy
  end

  test "reports_count decrements when destroying a report" do
    # Create a trusted reporter user
    reporter = User.create!(
      username: "reporter_#{SecureRandom.hex(4)}",
      email: "reporter_#{SecureRandom.hex(4)}@example.com",
      github_id: SecureRandom.random_number(1_000_000),
      name: "Reporter User",
      published_posts_count: 5,
      published_comments_count: 15
    )

    post = @user.posts.create!(
      title: "Test Post",
      content: "Test content",
      category: @category,
      published: true
    )

    report = reporter.reports.create!(
      post: post,
      reason: :spam
    )

    post.reload
    initial_count = post.reports_count

    report.destroy

    post.reload
    assert_equal initial_count - 1, post.reports_count

    reporter.destroy
  end

  test "counter caches remain accurate after multiple operations" do
    # Start with clean slate
    assert_equal 0, @user.published_posts_count
    assert_equal 0, @user.published_comments_count

    # Create 3 published posts
    3.times do |i|
      @user.posts.create!(
        title: "Published Post #{i}",
        content: "Content #{i}",
        category: @category,
        published: true
      )
    end

    # Create 2 unpublished posts
    2.times do |i|
      @user.posts.create!(
        title: "Unpublished Post #{i}",
        content: "Content #{i}",
        category: @category,
        published: false
      )
    end

    @user.reload
    assert_equal 3, @user.published_posts_count
    assert_equal @user.posts.published.count, @user.published_posts_count

    # Create comments on the first published post
    post = @user.posts.published.first

    # Create 5 published comments
    5.times do |i|
      @user.comments.create!(
        body: "Published comment #{i}",
        post: post,
        published: true
      )
    end

    # Create 3 unpublished comments
    3.times do |i|
      @user.comments.create!(
        body: "Unpublished comment #{i}",
        post: post,
        published: false
      )
    end

    @user.reload
    assert_equal 5, @user.published_comments_count
    assert_equal @user.comments.published.count, @user.published_comments_count

    # Unpublish one post
    @user.posts.published.first.update!(published: false)

    @user.reload
    assert_equal 2, @user.published_posts_count
    assert_equal @user.posts.published.count, @user.published_posts_count

    # Publish one unpublished comment
    @user.comments.where(published: false).first.update!(published: true)

    @user.reload
    assert_equal 6, @user.published_comments_count
    assert_equal @user.comments.published.count, @user.published_comments_count
  end
end
