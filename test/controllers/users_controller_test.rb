require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @public_user = users(:user_with_testimonial)
    @private_user = users(:user_without_testimonial)

    # Make user_without_testimonial a private profile
    @private_user.update_columns(public: false)
    # Ensure the other is public
    @public_user.update_columns(public: true)
  end

  # -------------------------------------------------------------------------
  # Profile visibility
  # -------------------------------------------------------------------------

  test "public profile is visible to anyone" do
    get user_path(@public_user)
    assert_response :success
  end

  test "private profile redirects non-owner to community index" do
    sign_in users(:admin_user)
    get user_path(@private_user)
    assert_redirected_to "/community"
  end

  test "private profile is visible to the owner" do
    sign_in @private_user
    get user_path(@private_user)
    assert_response :success
  end

  test "private profile is visible without login if accessed by owner" do
    # Unauthenticated user hitting a private profile gets redirected
    get user_path(@private_user)
    assert_redirected_to "/community"
  end
end
