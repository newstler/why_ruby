require "test_helper"

class GenerateTestimonialFieldsJobTest < ActiveJob::TestCase
  test "sets error feedback when no AI provider is configured" do
    testimonial = testimonials(:unpublished)

    # In test environment, no AI credentials should be configured
    # Job should gracefully handle this and set feedback
    GenerateTestimonialFieldsJob.perform_now(testimonial)

    testimonial.reload
    assert testimonial.ai_feedback.present?
  end

  test "enqueues without error" do
    testimonial = testimonials(:unpublished)

    assert_nothing_raised do
      GenerateTestimonialFieldsJob.perform_later(testimonial)
    end
  end
end
