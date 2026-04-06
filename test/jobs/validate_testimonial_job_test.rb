require "test_helper"

class ValidateTestimonialJobTest < ActiveJob::TestCase
  test "enqueues without error" do
    testimonial = testimonials(:unpublished)

    assert_nothing_raised do
      ValidateTestimonialJob.perform_later(testimonial)
    end
  end
end
