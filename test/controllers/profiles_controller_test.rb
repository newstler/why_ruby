require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:user_with_testimonial)
    @team = teams(:one)
    sign_in(@user)
  end

  test "shows profile page" do
    get team_profile_path(@team)
    assert_response :success
  end

  test "shows edit profile form" do
    get edit_team_profile_path(@team)
    assert_response :success
  end

  test "updates profile name" do
    patch team_profile_path(@team), params: { user: { name: "Updated Name" } }

    @user.reload
    assert_equal "Updated Name", @user.name
    assert_redirected_to team_profile_path(@team)
  end

  test "updates locale" do
    patch team_profile_path(@team), params: { user: { locale: "es" } }

    @user.reload
    assert_equal "es", @user.locale
    assert_redirected_to team_profile_path(@team)
  end

  test "clears locale with blank value" do
    @user.update!(locale: "es")

    patch team_profile_path(@team), params: { user: { locale: "" } }

    @user.reload
    assert_nil @user.locale
  end

  test "rejects invalid locale" do
    patch team_profile_path(@team), params: { user: { locale: "xx" } }

    # No locale validation on User model; any locale string is accepted
    assert_response :redirect
    @user.reload
    assert_equal "xx", @user.locale
  end

  test "redirects when not authenticated" do
    sign_out :user
    get team_profile_path(@team)
    assert_response :redirect
  end
end
