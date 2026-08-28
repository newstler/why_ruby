module Testimonial::AiValidatable
  extend ActiveSupport::Concern

  MAX_VALIDATION_ATTEMPTS = 3

  def validate_with_ai!
    existing = Testimonial.published.where.not(id: id)
      .pluck(:heading, :quote)
      .map { |h, q| "Heading: #{h}, Quote: #{q}" }
      .join("\n")

    system_prompt = build_validation_prompt(existing)

    user_prompt = <<~PROMPT
      Quote: #{quote}
      Generated heading: #{heading}
      Generated subheading: #{subheading}
      Generated body: #{body_text}
    PROMPT

    chat = user.chats.create!(
      purpose: "testimonial_validation",
      model: Model.resolve(Setting.get(:validation_model, default: Setting::DEFAULT_AI_MODEL))
    )

    response = chat.ask("#{system_prompt}\n\n#{user_prompt}")
    parsed = JSON.parse(response.content)

    if parsed["publish"]
      update!(published: true, ai_feedback: parsed["feedback"], reject_reason: nil)
    elsif parsed["reject_reason"] == "quote"
      update!(published: false, ai_feedback: parsed["feedback"], reject_reason: "quote")
    elsif ai_attempts < MAX_VALIDATION_ATTEMPTS
      update!(
        ai_attempts: ai_attempts + 1,
        ai_feedback: parsed["feedback"],
        reject_reason: "generation",
        published: false
      )
      GenerateTestimonialJob.perform_later(self)
    else
      update!(published: false, ai_feedback: parsed["feedback"], reject_reason: "generation")
    end

    broadcast_testimonial_update
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse validation response for testimonial #{id}: #{e.message}"
    update!(ai_feedback: "We couldn't validate your testimonial right now. Please try again later.")
    broadcast_testimonial_update
  rescue => e
    Rails.logger.error "Failed to validate testimonial #{id}: #{e.message}"
    update!(ai_feedback: "We couldn't validate your testimonial right now. Please try again later.")
    broadcast_testimonial_update
  end

  private

  def build_validation_prompt(existing_testimonials)
    <<~PROMPT
      You validate testimonials for a Ruby programming language advocacy site.

      CONTENT POLICY:
      - Hate speech, slurs, personal attacks, or targeted insults toward individuals or groups are NEVER allowed.
      - Casual expletives used positively (e.g., "Damn, Ruby is amazing!" or "Fuck, I love this language!") are ALLOWED.
      - The key distinction: profanity expressing enthusiasm = OK. Profanity attacking or demeaning people/groups = NOT OK.
      - The quote MUST express genuine love or appreciation for Ruby (or Ruby's ecosystem, community, tooling, or the developer experience it enables). This is an advocacy site — negative, dismissive, sarcastic, or trolling sentiments about Ruby are NOT allowed.
      - The quote MUST be a first-person testimonial ABOUT Ruby. It is NOT a place for:
          * user bios, résumés, or "about me" text (e.g., "Rails developer from South Korea, RFID specialist")
          * lists of the user's projects, employers, job titles, contact info, links, or credentials
          * generic descriptions of what Ruby is used for, with no personal sentiment attached
          * off-topic content (other languages, unrelated announcements, self-promotion)
        If the quote reads like a profile blurb, CV bullet, or product pitch rather than "here is why I love Ruby", reject it with reject_reason "quote".
      - The quote MUST be primarily about Ruby. Reject if Ruby is a passing mention and the real subject is another language or the author's own project.
      - The quote MUST be coherent, readable prose. Reject text that is garbled, unfinished, or impossible to follow.
      - The quote MUST NOT sell anything. Reject agency pitches, availability-for-hire notes, growth claims used as marketing ("we ship at 30x speed"), or any call to action.

      REJECTION EXAMPLES — these are all reject_reason "quote". Judge new quotes at this standard:
        * "800+ apps. All Rails. Ruby's clean syntax makes it the best for AI development. We ship at 30x speed. I help founders and teams build, scale, and ship Rails apps fast. Let's build something. Visit example.com"
          → REJECT: lead-generation advertising with a call to action, not a testimonial.
        * "Using Ruby and Rails to help UK heritage get funding. Read my blog here: https://example.com/@me"
          → REJECT: a link dump. States what the author does, never says anything about loving Ruby.
        * "Simplicity, elegance and happiness. Like where on earth do you see unless being used."
          → REJECT: incoherent, the second sentence does not parse.
        * "It's very convenient for small build scripts. I usually use Rake for tiny tasks. This is because why there is Rakefile in my Rust project."
          → REJECT: broken grammar, and the subject is the author's Rust project rather than a love of Ruby.

      ACCEPTANCE EXAMPLES — publish quotes of this kind even when short or plainly worded:
        * "I love Ruby because I can build my MVP in a few days." → ACCEPT: brief, but a genuine first-person reason.
        * "Ruby was my first love... It's a joy to work with. User-friendly, versatile and productive." → ACCEPT.
        * "I came to Ruby from Perl and PHP years ago and still can't leave. I also love Elixir." → ACCEPT: mentions other languages but the sentiment is clearly for Ruby.

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
      #{existing_testimonials.presence || "None yet."}

      Respond with valid JSON only: {"publish": true/false, "reject_reason": "quote" or "generation" or null, "feedback": "..."}
      - reject_reason "quote": the user's quote violates content policy or is not meaningful. Feedback should tell the USER what to fix.
      - reject_reason "generation": quote is fine but generated fields have a specific problem. Feedback must be a SPECIFIC INSTRUCTION for the AI generator, e.g., "The heading 'X' is already taken, use a different word" or "The body contradicts the quote by saying Y when the user said Z". Be concrete.
      - reject_reason null: publishing. Feedback should be a short positive note for the user.
    PROMPT
  end
end
