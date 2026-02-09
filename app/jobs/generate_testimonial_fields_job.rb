class GenerateTestimonialFieldsJob < ApplicationJob
  queue_as :default

  MAX_HEADING_RETRIES = 3

  def perform(testimonial)
    existing_headings = Testimonial.where.not(id: testimonial.id).where.not(heading: nil).pluck(:heading)

    user = testimonial.user
    user_context = [ user.display_name, user.bio, user.company ].compact_blank.join(", ")

    system_prompt = build_system_prompt(existing_headings)
    user_prompt = "User: #{user_context}\nQuote: #{testimonial.quote}"

    if testimonial.ai_feedback.present? && testimonial.ai_attempts > 0
      user_prompt += "\n\nPrevious feedback to address: #{testimonial.ai_feedback}"
    end

    parsed = generate_fields(system_prompt, user_prompt)

    unless parsed
      Rails.logger.error "Failed to generate testimonial fields for testimonial #{testimonial.id}"
      testimonial.update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
      broadcast_update(testimonial)
      return
    end

    # If the heading collides, retry with the rejected heading added to the exclusion list
    retries = 0
    while heading_taken?(parsed["heading"], testimonial.id) && retries < MAX_HEADING_RETRIES
      retries += 1
      existing_headings << parsed["heading"]
      retry_prompt = build_system_prompt(existing_headings)
      parsed = generate_fields(retry_prompt, user_prompt)
      break unless parsed
    end

    unless parsed
      testimonial.update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
      broadcast_update(testimonial)
      return
    end

    testimonial.update!(
      heading: parsed["heading"],
      subheading: parsed["subheading"],
      body_text: parsed["body_text"]
    )
    ValidateTestimonialJob.perform_later(testimonial)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse AI response for testimonial #{testimonial.id}: #{e.message}"
    testimonial.update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
    broadcast_update(testimonial)
  end

  private

  def build_system_prompt(existing_headings)
    taken = if existing_headings.any?
              "These headings are ALREADY TAKEN and must NOT be used (pick a synonym or related concept instead): #{existing_headings.join(', ')}."
    else
              "No headings are taken yet — pick any fitting word."
    end

    <<~PROMPT
      You generate structured testimonial content for a Ruby programming language advocacy site.
      Given a user's quote about why they love Ruby, generate:

      1. heading: A single unique 1-2 word heading that captures the THEME of the quote (e.g., "Elegance", "Joy", "Craft").
         #{taken}
      2. subheading: A short tagline under 10 words.
      3. body_text: 2-3 sentences that EXTEND and DEEPEN the user's idea — add new angles, examples, or implications.
         Do NOT repeat or paraphrase what the user already said. Build on top of it.

      WRITING STYLE — sound like a real person, not an AI:
      - NEVER use: delve, tapestry, landscape, foster, showcase, underscore, pivotal, vibrant, crucial, testament, additionally, interplay, intricate, enduring, garner, enhance
      - NEVER use inflated phrases: "serves as", "stands as", "is a testament to", "highlights the importance of", "reflects broader", "setting the stage"
      - NEVER use "It's not just X, it's Y" or "Not only X but also Y" parallelisms
      - NEVER use rule-of-three lists (e.g., "elegant, expressive, and powerful")
      - NEVER end with vague positivity ("the future looks bright", "exciting times ahead")
      - AVOID -ing tack-ons: "ensuring...", "highlighting...", "fostering..."
      - AVOID em dashes. Use commas or periods instead.
      - AVOID filler: "In order to", "It is important to note", "Due to the fact that"
      - USE simple verbs: "is", "has", "does" — not "serves as", "boasts", "features"
      - BE specific and concrete. Say what Ruby actually does, not how significant it is.
      - Write like a developer talking to a friend, not a press release.

      Respond with valid JSON only: {"heading": "...", "subheading": "...", "body_text": "..."}
    PROMPT
  end

  def generate_fields(system_prompt, user_prompt)
    result = nil

    if anthropic_configured?
      result = generate_with_anthropic(system_prompt, user_prompt)
    end

    if result.nil? && openai_configured?
      result = generate_with_openai(system_prompt, user_prompt)
    end

    result ? JSON.parse(result) : nil
  end

  def broadcast_update(testimonial)
    Turbo::StreamsChannel.broadcast_replace_to(
      "testimonial_#{testimonial.id}",
      target: "testimonial_section",
      partial: "testimonials/section",
      locals: { testimonial: testimonial, user: testimonial.user }
    )
  end

  def heading_taken?(heading, testimonial_id)
    Testimonial.where.not(id: testimonial_id).exists?(heading: heading)
  end

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
        max_tokens: 300,
        temperature: 0.7,
        system: system_prompt,
        messages: [ { role: "user", content: user_prompt } ]
      }
    )

    response.dig("content", 0, "text")
  rescue => e
    Rails.logger.error "Anthropic API error in GenerateTestimonialFieldsJob: #{e.message}"
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
        temperature: 0.7,
        max_tokens: 300
      }
    )

    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "OpenAI API error in GenerateTestimonialFieldsJob: #{e.message}"
    nil
  end
end
