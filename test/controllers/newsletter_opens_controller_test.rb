require "test_helper"

class NewsletterOpensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:user_with_testimonial)
  end

  test "valid token records open and returns GIF" do
    token = @user.newsletter_open_token(1)

    get newsletter_open_path(token: token)

    assert_response :success
    assert_equal "image/gif", response.content_type
    @user.reload
    assert_includes @user.newsletters_opened, 1
  end

  test "invalid token still returns GIF" do
    get newsletter_open_path(token: "invalid-token")

    assert_response :success
    assert_equal "image/gif", response.content_type
  end

  test "duplicate open is idempotent" do
    token = @user.newsletter_open_token(1)

    get newsletter_open_path(token: token)
    get newsletter_open_path(token: token)

    @user.reload
    assert_equal [ 1 ], @user.newsletters_opened
  end
end
