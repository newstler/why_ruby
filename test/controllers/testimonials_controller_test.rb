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

    valid_quote = "I love Ruby because it makes coding joyful. Ruby has transformed my development experience with its elegant syntax and expressive power that makes every day a pleasure."

    assert_difference "Testimonial.count", 1 do
      post testimonial_path, params: { testimonial: { quote: valid_quote } }
    end

    assert_redirected_to user_path(user)
    assert_equal valid_quote, user.reload.testimonial.quote
  end

  test "authenticated user can update testimonial" do
    user = users(:user_with_testimonial)
    sign_in user

    updated_quote = "Updated: I love Ruby even more now! The community is amazing and the language keeps getting better. Ruby on Rails has made web development a true joy for me over the years."

    patch testimonial_path, params: { testimonial: { quote: updated_quote } }

    assert_redirected_to user_path(user)
    assert_equal updated_quote, user.reload.testimonial.quote
  end

  test "cannot create testimonial with quote too short" do
    user = users(:user_no_testimonial)
    sign_in user

    assert_no_difference "Testimonial.count" do
      post testimonial_path, params: { testimonial: { quote: "Too short" } }
    end
  end

  test "can create testimonial with blank quote" do
    user = users(:user_no_testimonial)
    sign_in user

    assert_difference "Testimonial.count", 1 do
      post testimonial_path, params: { testimonial: { quote: "" } }
    end

    assert_redirected_to user_path(user)
  end
end
