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

  test "validates uniqueness of user_id" do
    existing = testimonials(:published)
    duplicate = Testimonial.new(
      user_id: existing.user_id,
      quote: "Another quote"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "validates uniqueness of heading allowing nil" do
    existing = testimonials(:published)
    other_user = users(:user_no_testimonial)
    new_testimonial = Testimonial.new(
      user: other_user,
      quote: "My quote",
      heading: existing.heading
    )
    assert_not new_testimonial.valid?
    assert_includes new_testimonial.errors[:heading], "has already been taken"
  end

  test "allows nil heading" do
    testimonial = testimonials(:unpublished)
    assert_nil testimonial.heading
    assert testimonial.valid?
  end

  test "published scope returns only published testimonials" do
    published = Testimonial.published
    assert published.all?(&:published?)
    assert_includes published, testimonials(:published)
    assert_not_includes published, testimonials(:unpublished)
  end

  test "ordered scope sorts by position asc nulls last then created_at desc" do
    ordered = Testimonial.ordered
    positioned = ordered.select(&:position)
    assert_equal positioned, positioned.sort_by(&:position)
  end

  test "one testimonial per user" do
    user = users(:user_with_testimonial)
    assert user.testimonial.present?
    new_testimonial = Testimonial.new(user: user, quote: "New quote")
    assert_not new_testimonial.valid?
  end

  test "belongs to user" do
    testimonial = testimonials(:published)
    assert_equal users(:user_with_testimonial), testimonial.user
  end
end
