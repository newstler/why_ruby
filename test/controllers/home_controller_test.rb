require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows home page when not authenticated" do
    get root_path
    assert_response :success
  end

  test "shows team home page when authenticated with team" do
    user = users(:user_with_testimonial)
    team = teams(:one)
    sign_in(user)

    get team_root_path(team)
    assert_response :success
  end

  test "shows teams index when accessing root while authenticated with multiple teams" do
    user = users(:user_with_testimonial) # User one has 2 teams per fixtures
    sign_in(user)

    get root_path
    # With multiple teams, shows the team selection page
    assert_response :success
  end
end
