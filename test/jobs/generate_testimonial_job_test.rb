require "test_helper"

class GenerateTestimonialJobTest < ActiveJob::TestCase
  test "enqueues without error" do
    testimonial = testimonials(:unpublished)

    assert_nothing_raised do
      GenerateTestimonialJob.perform_later(testimonial)
    end
  end
end
