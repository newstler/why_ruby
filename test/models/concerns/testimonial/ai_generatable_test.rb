require "test_helper"

class Testimonial::AiGeneratableTest < ActiveSupport::TestCase
  setup do
    @published_testimonial = testimonials(:published)
    @unpublished_testimonial = testimonials(:unpublished)
  end

  # -------------------------------------------------------------------------
  # heading_taken? logic
  # -------------------------------------------------------------------------

  test "heading_taken? returns true when heading exists on another testimonial" do
    # "Joy" is the heading of the published fixture
    assert @unpublished_testimonial.send(:heading_taken?, "Joy")
  end

  test "heading_taken? returns false for a unique heading" do
    assert_not @unpublished_testimonial.send(:heading_taken?, "UniqueHeadingThatDoesNotExist")
  end

  test "heading_taken? ignores own heading" do
    # The published testimonial has heading "Joy" — it should not flag itself
    assert_not @published_testimonial.send(:heading_taken?, "Joy")
  end
end
