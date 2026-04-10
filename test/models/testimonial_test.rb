require "test_helper"

class TestimonialTest < ActiveSupport::TestCase
  test "validates quote length minimum 140 characters" do
    testimonial = Testimonial.new(user: users(:user_no_testimonial), quote: "Too short")
    assert_not testimonial.valid?
    assert testimonial.errors[:quote].any? { |e| e.include?("too short") }
  end

  test "allows blank quote" do
    testimonial = Testimonial.new(user: users(:user_no_testimonial), quote: "")
    assert testimonial.valid?
  end

  test "one testimonial per user" do
    user = users(:user_with_testimonial)
    assert user.testimonial.present?
    new_testimonial = Testimonial.new(user: user, quote: "New quote")
    assert_not new_testimonial.valid?
  end
end
