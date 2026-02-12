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

      CONTENT POLICY:
      - Hate speech, slurs, personal attacks, or targeted insults toward individuals or groups are NEVER allowed.
      - Casual expletives used positively (e.g., "Damn, Ruby is amazing!" or "Fuck, I love this language!") are ALLOWED.
      - The key distinction: profanity expressing enthusiasm = OK. Profanity attacking or demeaning people/groups = NOT OK.
      - The quote MUST express genuine love or appreciation for Ruby. This is an advocacy site — negative, dismissive, sarcastic, or trolling sentiments about Ruby are NOT allowed.

      VALIDATION RULES:
      1. First check the user's QUOTE against the content policy. If it violates (including being negative about Ruby), reject immediately with reject_reason "quote".
      2. If the quote is fine, check the AI-generated fields (heading/subheading/body). ONLY reject generation if there is a CLEAR problem:
         - The body contradicts or misrepresents the quote
         - The subheading is nonsensical or unrelated
         - The content is factually wrong about Ruby
         Do NOT reject for duplicate headings (handled elsewhere). Do NOT reject just because the fields could be "better" or "more creative". Good enough is good enough — publish it.
      3. If everything looks acceptable, publish it.

      AI-SOUNDING LANGUAGE CHECK:
      Reject with reason "generation" if the generated heading/subheading/body contains:
      - Words: delve, tapestry, landscape, foster, showcase, underscore, pivotal, vibrant, crucial, testament, additionally, interplay, intricate, enduring, garner, enhance
      - Patterns: "serves as", "stands as", "is a testament to", "not just X, it's Y", "not only X but also Y"
      - Rule-of-three adjective/noun lists
      - Vague positive endings ("the future looks bright", "exciting times ahead")
      - Superficial -ing tack-ons ("ensuring...", "highlighting...", "fostering...")
      If the quote itself is fine but the generated text sounds like AI wrote it, set reject_reason to "generation" and explain which phrases sound artificial.

      Existing published testimonials (for context):
      #{existing.presence || "None yet."}

      Respond with valid JSON only: {"publish": true/false, "reject_reason": "quote" or "generation" or null, "feedback": "..."}
      - reject_reason "quote": the user's quote violates content policy or is not meaningful. Feedback should tell the USER what to fix.
      - reject_reason "generation": quote is fine but generated fields have a specific problem. Feedback must be a SPECIFIC INSTRUCTION for the AI generator, e.g., "The heading 'X' is already taken, use a different word" or "The body contradicts the quote by saying Y when the user said Z". Be concrete.
      - reject_reason null: publishing. Feedback should be a short positive note for the user.
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
        testimonial.update!(published: true, ai_feedback: parsed["feedback"], reject_reason: nil)
      elsif parsed["reject_reason"] == "quote"
        testimonial.update!(
          published: false,
          ai_feedback: parsed["feedback"],
          reject_reason: "quote"
        )
      elsif testimonial.ai_attempts < MAX_ATTEMPTS
        testimonial.update!(
          ai_attempts: testimonial.ai_attempts + 1,
          ai_feedback: parsed["feedback"],
          reject_reason: "generation",
          published: false
        )
        GenerateTestimonialFieldsJob.perform_later(testimonial)
      else
        testimonial.update!(
          published: false,
          ai_feedback: parsed["feedback"],
          reject_reason: "generation"
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
        max_tokens: 300,
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
        max_tokens: 300
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
      target: "testimonial_section",
      partial: "testimonials/section",
      locals: { testimonial: testimonial, user: testimonial.user }
    )
  end
end
