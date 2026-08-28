# Quotes arrive in whatever language the author writes in. The book and the site
# are English, so a non-English quote is translated to English before it can be
# published — and the author's own words are kept in quote_original, never lost.
module Testimonial::AiTranslatable
  extend ActiveSupport::Concern

  ENGLISH = "en".freeze

  LANGUAGE_NAMES = {
    "english" => "en", "italian" => "it", "spanish" => "es", "portuguese" => "pt",
    "french" => "fr", "german" => "de", "russian" => "ru", "ukrainian" => "uk",
    "japanese" => "ja", "korean" => "ko", "chinese" => "zh", "turkish" => "tr",
    "polish" => "pl", "dutch" => "nl", "indonesian" => "id", "vietnamese" => "vi",
    "arabic" => "ar", "hindi" => "hi", "serbian" => "sr", "croatian" => "hr",
    "czech" => "cs", "romanian" => "ro", "greek" => "el", "hebrew" => "he",
    "swedish" => "sv", "norwegian" => "no", "danish" => "da", "finnish" => "fi"
  }.freeze

  def translated? = quote_original.present?

  def needs_translation? = quote.present? && !translated?

  # Detects the language and, when it isn't English, rewrites `quote` in English
  # while preserving the original. Returns true when a translation was written.
  def translate_to_english!
    return false if quote.blank?

    chat = user.chats.create!(
      purpose: "testimonial_translation",
      model: Model.resolve(Setting.get(:translation_model, default: Setting::DEFAULT_AI_MODEL))
    )

    parsed = JSON.parse(chat.ask(translation_prompt).content.strip.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, ""))
    language = normalize_language(parsed["language"])
    english = parsed["english"].to_s.strip.presence

    return false if language.nil? || language == ENGLISH
    return false if english.nil? || english == quote

    update!(
      quote_original: quote,
      quote_language: language,
      quote: english,
      system_generated: true
    )
    true
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse translation response for testimonial #{id}: #{e.message}"
    false
  rescue => e
    Rails.logger.error "Failed to translate testimonial #{id}: #{e.message}"
    false
  end

  private

  # Models answer this with either an ISO code ("it") or a name ("Italian"),
  # so accept both and always store the code.
  def normalize_language(value)
    raw = value.to_s.strip.downcase
    return nil if raw.blank?
    return LANGUAGE_NAMES[raw] if LANGUAGE_NAMES.key?(raw)
    return raw[0, 2] if raw.match?(/\A[a-z]{2}(-[a-z]{2,})?\z/)

    raw
  end

  def translation_prompt
    <<~PROMPT
      Identify the language of the testimonial below and translate it to English.

      Rules:
      - "language" is the ISO 639-1 code of the language the testimonial is written in.
      - If it is already English, return the code "en" and copy the text unchanged into "english".
      - A testimonial that is mostly English but quotes a phrase in another language counts as English.
      - Translate the WHOLE text. Never shorten, summarise, omit or truncate any part of it.
      - Keep the author's voice, tone and any emoji. Do not add commentary.

      Testimonial:
      #{quote}

      Respond with valid JSON only: {"language": "xx", "english": "..."}
    PROMPT
  end
end
