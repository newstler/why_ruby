class GenerateTestimonialJob < ApplicationJob
  queue_as :default

  def perform(testimonial)
    # Translate first so the heading, subheading and body are written from the
    # English text rather than from a language the book does not print.
    testimonial.translate_to_english! if testimonial.needs_translation?
    testimonial.generate_ai_fields!
  end
end
