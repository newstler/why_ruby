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
end
