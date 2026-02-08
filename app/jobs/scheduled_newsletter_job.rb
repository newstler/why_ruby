# frozen_string_literal: true

class ScheduledNewsletterJob < ApplicationJob
  queue_as :default

  EXCLUDED_USERNAMES = %w[dhh matz pragdave amandaperino].freeze

  def perform(user_id, version:)
    user = User.find_by(id: user_id)
    return unless user
    return if user.received_newsletter?(version)
    return if user.unsubscribed_from_newsletter?
    return if user.email.end_with?("@users.noreply.github.com")
    return if EXCLUDED_USERNAMES.include?(user.username)

    NewsletterMailer.update(user, version: version).deliver_now
    user.record_newsletter_sent!(version)
  end
end
