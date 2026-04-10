require "test_helper"

class PostTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:user_with_testimonial)
    @category = categories(:general)
    @success_category = categories(:success_stories)
  end

  # -------------------------------------------------------------------------
  # Content type validation
  # -------------------------------------------------------------------------

  test "article requires content" do
    post = Post.new(title: "Test Article", post_type: "article", user: @user, category: @category)
    assert_not post.valid?
    assert_includes post.errors[:content], "is required for articles"
  end

  test "article rejects url" do
    post = Post.new(
      title: "Test Article", post_type: "article",
      content: "Some content", url: "https://example.com",
      user: @user, category: @category
    )
    assert_not post.valid?
    assert_includes post.errors[:url], "must be blank for articles"
  end

  test "link requires url" do
    post = Post.new(title: "Test Link", post_type: "link", user: @user, category: @category)
    assert_not post.valid?
    assert_includes post.errors[:url], "is required for external links"
  end

  test "link rejects content" do
    post = Post.new(
      title: "Test Link", post_type: "link",
      url: "https://example.com", content: "Some content",
      user: @user, category: @category
    )
    assert_not post.valid?
    assert_includes post.errors[:content], "must be blank for external links"
  end

  test "success story requires logo_svg" do
    post = Post.new(
      title: "Test Story", post_type: "success_story",
      content: "Story content",
      user: @user, category: @success_category
    )
    assert_not post.valid?
    assert_includes post.errors[:logo_svg], "is required for success stories"
  end

  test "success story requires content" do
    post = Post.new(
      title: "Test Story", post_type: "success_story",
      logo_svg: "<svg><path d='M0 0'/></svg>",
      user: @user, category: @success_category
    )
    assert_not post.valid?
    assert_includes post.errors[:content], "is required for success stories"
  end

  test "success story rejects url" do
    post = Post.new(
      title: "Test Story", post_type: "success_story",
      logo_svg: "<svg><path d='M0 0'/></svg>", content: "Story content",
      url: "https://example.com",
      user: @user, category: @success_category
    )
    assert_not post.valid?
    assert_includes post.errors[:url], "must be blank for success stories"
  end

  # -------------------------------------------------------------------------
  # SVG sanitization
  # -------------------------------------------------------------------------

  test "sanitizes script tags from logo_svg before validation" do
    post = Post.new(
      title: "Test Story", post_type: "success_story",
      content: "Story content",
      logo_svg: "<svg><script>alert('xss')</script><path d='M0 0'/></svg>",
      user: @user, category: @success_category
    )
    post.valid? # triggers before_validation callback
    assert_not_includes post.logo_svg, "<script"
    assert_not_includes post.logo_svg, "</script>"
  end

  test "sanitizes javascript event handlers from logo_svg" do
    post = Post.new(
      title: "Test Story", post_type: "success_story",
      content: "Story content",
      logo_svg: "<svg><path onclick='alert(1)' d='M0 0'/></svg>",
      user: @user, category: @success_category
    )
    post.valid?
    assert_not_includes post.logo_svg, "onclick"
  end

  test "preserves valid SVG content after sanitization" do
    valid_svg = "<svg viewBox='0 0 100 100'><path fill='red' d='M0 0 L100 100'/></svg>"
    post = Post.new(
      title: "Test Story", post_type: "success_story",
      content: "Story content",
      logo_svg: valid_svg,
      user: @user, category: @success_category
    )
    post.valid?
    assert_includes post.logo_svg, "<svg"
    assert_includes post.logo_svg, "path"
  end

  # -------------------------------------------------------------------------
  # Auto-hide moderation
  # -------------------------------------------------------------------------

  test "auto_hide_if_needed! hides post with 3 or more reports" do
    post = posts(:at_threshold_post)
    assert post.published?
    assert_not post.needs_admin_review?

    post.auto_hide_if_needed!
    post.reload

    assert_not post.published?
    assert post.needs_admin_review?
  end

  test "auto_hide_if_needed! does not hide post with fewer than 3 reports" do
    post = posts(:near_threshold_post)
    assert_equal 2, post.reports_count
    assert post.published?

    post.auto_hide_if_needed!
    post.reload

    assert post.published?
    assert_not post.needs_admin_review?
  end

  # -------------------------------------------------------------------------
  # URL normalization
  # -------------------------------------------------------------------------

  test "normalizes http to https for github.com" do
    post = Post.new(
      title: "GitHub Link", post_type: "link",
      url: "http://github.com/rails/rails",
      user: @user, category: @category
    )
    post.valid? # triggers before_validation :normalize_url
    assert_equal "https://github.com/rails/rails", post.url
  end

  test "strips trailing slashes from url" do
    post = Post.new(
      title: "Link with trailing slash", post_type: "link",
      url: "https://example.com/page/",
      user: @user, category: @category
    )
    post.valid?
    assert_equal "https://example.com/page", post.url
  end

  test "strips multiple trailing slashes from url" do
    post = Post.new(
      title: "Link with trailing slashes", post_type: "link",
      url: "https://example.com/page///",
      user: @user, category: @category
    )
    post.valid?
    assert_equal "https://example.com/page", post.url
  end

  # -------------------------------------------------------------------------
  # Summary generation enqueueing
  # -------------------------------------------------------------------------

  test "enqueues GenerateSummaryJob on create when summary is blank" do
    assert_enqueued_with(job: GenerateSummaryJob) do
      Post.create!(
        title: "New Article", post_type: "article",
        content: "Some article content here.",
        summary: "",
        user: @user, category: @category
      )
    end
  end

  test "does not enqueue GenerateSummaryJob on create when summary is present" do
    assert_no_enqueued_jobs(only: GenerateSummaryJob) do
      Post.create!(
        title: "Article with Summary", post_type: "article",
        content: "Some article content here.",
        summary: "Already summarized.",
        user: @user, category: @category
      )
    end
  end
end
