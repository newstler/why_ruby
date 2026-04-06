class GenerateTestimonialJob < ApplicationJob
  queue_as :default

  def perform(testimonial)
    testimonial.generate_ai_fields!
  end
end
