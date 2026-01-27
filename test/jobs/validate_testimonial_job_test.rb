require "test_helper"

class ValidateTestimonialJobTest < ActiveJob::TestCase
  test "sets error feedback when no AI provider is configured" do
    testimonial = testimonials(:unpublished)
    testimonial.update_columns(heading: "TestHeading", subheading: "Test sub", body_text: "Test body")

    # In test environment, no AI credentials should be configured
    ValidateTestimonialJob.perform_now(testimonial)

    testimonial.reload
    assert testimonial.ai_feedback.present?
  end

  test "enqueues without error" do
    testimonial = testimonials(:unpublished)

    assert_nothing_raised do
      ValidateTestimonialJob.perform_later(testimonial)
    end
  end
end
