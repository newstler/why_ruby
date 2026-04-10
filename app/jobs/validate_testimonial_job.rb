class ValidateTestimonialJob < ApplicationJob
  queue_as :default

  def perform(testimonial)
    testimonial.validate_with_ai!
  end
end
