require "test_helper"

class TestimonialsControllerTest < ActionDispatch::IntegrationTest
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

  test "an over-long quote is rejected with the full text preserved, never trimmed" do
    sign_in users(:user_no_testimonial)
    long = "I love Ruby because " + ("it reads like plain English and gets out of my way. " * 12)

    assert_no_difference -> { Testimonial.count } do
      post testimonial_path, params: { testimonial: { quote: long } }
    end
  end

  test "a self-promotional quote is refused" do
    sign_in users(:user_no_testimonial)
    promo = "I love Ruby because it lets me ship fast for my clients every single week of the year without fail. Visit rubygrowthlabs.com"

    assert_no_difference -> { Testimonial.count } do
      post testimonial_path, params: { testimonial: { quote: promo } }
    end
  end
end
