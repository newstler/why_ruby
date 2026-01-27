require "test_helper"

class TestimonialsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "unauthenticated user cannot create testimonial" do
    post testimonial_path, params: { testimonial: { quote: "I love Ruby!" } }
    assert_response :redirect
  end

  test "authenticated user can create testimonial" do
    user = users(:user_no_testimonial)
    sign_in user

    assert_difference "Testimonial.count", 1 do
      post testimonial_path, params: { testimonial: { quote: "I love Ruby because it sparks joy!" } }
    end

    assert_redirected_to user_path(user)
    assert_equal "I love Ruby because it sparks joy!", user.reload.testimonial.quote
  end

  test "authenticated user can update testimonial" do
    user = users(:user_with_testimonial)
    sign_in user

    patch testimonial_path, params: { testimonial: { quote: "Updated: I love Ruby even more!" } }

    assert_redirected_to user_path(user)
    assert_equal "Updated: I love Ruby even more!", user.reload.testimonial.quote
  end

  test "cannot create testimonial without quote" do
    user = users(:user_no_testimonial)
    sign_in user

    assert_no_difference "Testimonial.count" do
      post testimonial_path, params: { testimonial: { quote: "" } }
    end

    assert_redirected_to user_path(user)
  end
end
