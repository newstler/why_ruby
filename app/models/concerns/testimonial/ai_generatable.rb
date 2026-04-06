module Testimonial::AiGeneratable
  extend ActiveSupport::Concern

  MAX_HEADING_RETRIES = 5

  def generate_ai_fields!
    existing_headings = Testimonial.where.not(id: id).where.not(heading: nil).pluck(:heading)

    user_context = [ user.display_name, user.bio, user.company ].compact_blank.join(", ")
    system_prompt = build_generation_prompt(existing_headings)
    user_prompt = "User: #{user_context}\nQuote: #{quote}"

    if ai_feedback.present? && ai_attempts > 0
      user_prompt += "\n\nPrevious feedback to address: #{ai_feedback}"
    end

    chat = user.chats.create!(
      purpose: "testimonial_generation",
      model: Model.find_by(model_id: RubyLLM.configuration.default_model)
    )

    parsed = ask_and_parse(chat, system_prompt, user_prompt)

    unless parsed
      update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
      broadcast_testimonial_update
      return
    end

    retries = 0
    while heading_taken?(parsed["heading"]) && retries < MAX_HEADING_RETRIES
      retries += 1
      existing_headings << parsed["heading"]
      retry_prompt = build_generation_prompt(existing_headings)
      parsed = ask_and_parse(chat, retry_prompt, user_prompt)
      break unless parsed
    end

    unless parsed
      update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
      broadcast_testimonial_update
      return
    end

    update!(
      heading: parsed["heading"],
      subheading: parsed["subheading"],
      body_text: parsed["body_text"]
    )
    ValidateTestimonialJob.perform_later(self)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse AI response for testimonial #{id}: #{e.message}"
    update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
    broadcast_testimonial_update
  end

  private

  def ask_and_parse(chat, system_prompt, user_prompt)
    response = chat.ask("#{system_prompt}\n\n#{user_prompt}")
    JSON.parse(response.content)
  rescue JSON::ParserError
    nil
  rescue => e
    Rails.logger.error "AI error in testimonial generation for #{id}: #{e.message}"
    nil
  end

  def heading_taken?(heading)
    Testimonial.where.not(id: id).exists?(heading: heading)
  end

  def build_generation_prompt(existing_headings)
    taken = if existing_headings.any?
              "These headings are ALREADY TAKEN and must NOT be used (pick a synonym or related concept instead): #{existing_headings.join(', ')}."
    else
              "No headings are taken yet — pick any fitting word."
    end

    <<~PROMPT
      You generate structured testimonial content for a Ruby programming language advocacy site.
      Given a user's quote about why they love Ruby, generate:

      1. heading: A unique 1-3 word heading that captures the THEME or FEELING of the quote.
         Be creative and specific. Go beyond generic words. Think of evocative nouns, metaphors, compound phrases, or poetic concepts.
         The heading must make sense as an answer to "Why Ruby?" — e.g. "Why Ruby?" → "Flow State", "Clarity", "Pure Joy".
         Good examples: "Spark", "Flow State", "Quiet Power", "Warm Glow", "First Love", "Playground", "Second Nature", "Deep Roots", "Readable Code", "Clean Slate", "Smooth Sailing", "Expressiveness", "Old Friend", "Sharp Tools", "Creative Freedom", "Solid Ground", "Calm Waters", "Poetic Logic", "Builder's Joy", "Sweet Spot", "Hidden Gem", "Fresh Start", "True North", "Clarity", "Belonging", "Empowerment", "Momentum", "Simplicity", "Trust", "Confidence"
         #{taken}
      2. subheading: A short tagline under 10 words.
      3. body_text: 2-3 sentences that EXTEND and DEEPEN the user's idea. Add new angles, examples, or implications.
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
end
