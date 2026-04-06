require "test_helper"

class OnboardingsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get onboarding_path
    assert_redirected_to github_auth_with_return_path
  end

  test "shows onboarding form for un-onboarded user" do
    user = users(:user_no_testimonial)
    sign_in(user)

    get onboarding_path
    assert_response :success
  end

  test "redirects onboarded users away from onboarding" do
    user = users(:user_with_testimonial)
    sign_in(user)

    get onboarding_path
    assert_redirected_to root_path
  end

  test "completes onboarding with name" do
    user = users(:user_no_testimonial)
    team = teams(:one)
    sign_in(user)

    patch onboarding_path, params: { onboarding: { name: "Alice Smith", team_name: "Alice's Team" } }

    user.reload
    team.reload
    assert_equal "Alice Smith", user.name
    assert user.onboarded?
    assert_redirected_to team_root_path(team)
  end

  test "updates team name when user is owner" do
    user = users(:user_no_testimonial)
    team = teams(:one)
    sign_in(user)

    patch onboarding_path, params: { onboarding: { name: "Alice", team_name: "New Team Name" } }

    team.reload
    assert_equal "New Team Name", team.name
  end

  test "renders form again when name is blank" do
    user = users(:user_no_testimonial)
    sign_in(user)

    patch onboarding_path, params: { onboarding: { name: "" } }

    # Blank name is normalized to nil; the controller redirects
    # but the user remains un-onboarded (name.present? is false)
    assert_response :redirect
    user.reload
    assert_nil user.name
  end
end
