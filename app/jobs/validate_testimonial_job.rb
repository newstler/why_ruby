class ValidateTestimonialJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 3

  def perform(testimonial)
    existing = Testimonial.published.where.not(id: testimonial.id)
      .pluck(:heading, :quote)
      .map { |h, q| "Heading: #{h}, Quote: #{q}" }
      .join("\n")

    system_prompt = <<~PROMPT
      You validate testimonials for a Ruby programming language advocacy site.
      Evaluate if this testimonial is meaningful, genuine, appropriate, and adds something new.
      Existing published testimonials:
      #{existing.presence || "None yet."}

      Respond with valid JSON only: {"publish": true/false, "feedback": "..."}
      If publish is false, provide constructive feedback the user can act on.
    PROMPT

    user_prompt = <<~PROMPT
      Quote: #{testimonial.quote}
      Generated heading: #{testimonial.heading}
      Generated subheading: #{testimonial.subheading}
      Generated body: #{testimonial.body_text}
    PROMPT

    result = nil

    if anthropic_configured?
      result = generate_with_anthropic(system_prompt, user_prompt)
    end

    if result.nil? && openai_configured?
      result = generate_with_openai(system_prompt, user_prompt)
    end

    if result
      parsed = JSON.parse(result)

      if parsed["publish"]
        testimonial.update!(published: true, ai_feedback: parsed["feedback"].presence || "Your testimonial has been published!")
      elsif testimonial.ai_attempts < MAX_ATTEMPTS
        testimonial.update!(
          ai_attempts: testimonial.ai_attempts + 1,
          ai_feedback: parsed["feedback"],
          published: false
        )
        GenerateTestimonialFieldsJob.perform_later(testimonial)
      else
        testimonial.update!(
          published: false,
          ai_feedback: parsed["feedback"].presence || "Your testimonial couldn't be published. Please try rewriting it."
        )
      end
    else
      Rails.logger.error "Failed to validate testimonial #{testimonial.id}"
      testimonial.update!(ai_feedback: "We couldn't validate your testimonial right now. Please try again later.")
    end

    broadcast_update(testimonial)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse validation response for testimonial #{testimonial.id}: #{e.message}"
    testimonial.update!(ai_feedback: "We couldn't validate your testimonial right now. Please try again later.")
    broadcast_update(testimonial)
  end

  private

  def anthropic_configured?
    Rails.application.credentials.dig(:anthropic, :api_key).present? ||
      Rails.application.credentials.dig(:anthropic, :access_token).present?
  end

  def openai_configured?
    Rails.application.credentials.dig(:openai, :api_key).present? ||
      Rails.application.credentials.dig(:openai, :access_token).present?
  end

  def generate_with_anthropic(system_prompt, user_prompt)
    api_key = Rails.application.credentials.dig(:anthropic, :api_key).presence ||
      Rails.application.credentials.dig(:anthropic, :access_token)

    client = Anthropic::Client.new(api_key: api_key)

    response = client.messages(
      parameters: {
        model: "claude-3-haiku-20240307",
        max_tokens: 200,
        temperature: 0.3,
        system: system_prompt,
        messages: [ { role: "user", content: user_prompt } ]
      }
    )

    response.dig("content", 0, "text")
  rescue => e
    Rails.logger.error "Anthropic API error in ValidateTestimonialJob: #{e.message}"
    nil
  end

  def generate_with_openai(system_prompt, user_prompt)
    token = Rails.application.credentials.dig(:openai, :api_key).presence ||
      Rails.application.credentials.dig(:openai, :access_token)

    client = OpenAI::Client.new(access_token: token)

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.3,
        max_tokens: 200
      }
    )

    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "OpenAI API error in ValidateTestimonialJob: #{e.message}"
    nil
  end

  def broadcast_update(testimonial)
    Turbo::StreamsChannel.broadcast_replace_to(
      "testimonial_#{testimonial.id}",
      target: "testimonial_form",
      partial: "testimonials/form",
      locals: { testimonial: testimonial, user: testimonial.user }
    )
  end
end
