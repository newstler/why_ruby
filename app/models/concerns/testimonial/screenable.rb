# Deterministic gate that runs before any AI call. Catches the two things the
# LLM validator kept waving through: quotes carrying links or contact details,
# and quotes that are a services pitch rather than "here is why I love Ruby".
module Testimonial::Screenable
  extend ActiveSupport::Concern

  URL = %r{https?://|\bwww\.}i
  EMAIL = /\b[\w.+-]+@[\w-]+\.[a-z]{2,}\b/i
  HANDLE = /(?:\A|\s)@[\w-]{2,}/
  # Bare domains, but only on TLDs people actually advertise with, so "Ruby 1.8"
  # and "rails.application.config" stay clear.
  DOMAIN = /\b[a-z0-9][\w-]*\.(?:com|net|org|io|dev|app|co|ai|me|xyz|team|fm|ch|info)\b/i

  PITCH = [
    /\b(?:visit|check\s+out|follow|subscribe\s+to|read)\s+(?:my|our|us\s+at)\b/i,
    /\b(?:hire|email|contact|dm|message|reach\s+out\s+to)\s+me\b/i,
    /\bi\s+help\s+\w+(?:\s+\w+){0,3}\s+(?:build|scale|ship|grow|launch)\b/i,
    /\bwe\s+(?:help|build|ship|scale)\s+(?:you|your|founders|teams|clients|companies)\b/i,
    /\blet'?s\s+(?:build|work|talk|connect)\b/i,
    /\b(?:available|open)\s+for\s+(?:hire|work|projects|contracts|opportunities)\b/i,
    /\bneed\s+help\s+with\s+yours\b/i
  ].freeze

  included do
    validate :quote_is_not_self_promotional, if: -> { quote.present? }
  end

  def self_promotional? = screening_feedback.present?

  # Nil when the quote is clean, otherwise the reason to show the author.
  # Keyed on the quote so editing the text in memory re-screens it.
  def screening_feedback
    @screening ||= {}
    @screening.fetch(quote) { @screening[quote] = detect_self_promotion }
  end

  private

  def detect_self_promotion
    text = quote.to_s
    return I18n.t("testimonials.screening.link") if text.match?(URL) || text.match?(EMAIL) ||
      text.match?(HANDLE) || text.match?(DOMAIN)
    return I18n.t("testimonials.screening.promotion") if PITCH.any? { |p| text.match?(p) }

    nil
  end

  def quote_is_not_self_promotional
    errors.add(:quote, screening_feedback) if self_promotional?
  end
end
