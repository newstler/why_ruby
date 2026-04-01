require "test_helper"

class Teams::PricingControllerTest < ActionDispatch::IntegrationTest
  test "redirects when not authenticated" do
    get team_pricing_path(teams(:one))
    assert_response :redirect
  end

  test "redirects non-admin members" do
    sign_in(users(:user_with_testimonial))
    # user_one is member (not admin) of team_two
    get team_pricing_path(teams(:two))
    assert_redirected_to team_root_path(teams(:two))
  end

  test "shows pricing page for admin" do
    sign_in(users(:user_with_testimonial))
    # Stub Price.all to avoid hitting Stripe
    original_method = Price.method(:all)
    Price.define_singleton_method(:all) do
      [ Price.new(id: "price_1", product_name: "Pro", unit_amount: 1900, currency: "usd", interval: "month", interval_count: 1) ]
    end

    get team_pricing_path(teams(:one))
    assert_response :success
  ensure
    Price.define_singleton_method(:all, original_method)
  end
end
