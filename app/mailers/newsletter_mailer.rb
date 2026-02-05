# frozen_string_literal: true

class NewsletterMailer < ApplicationMailer
  SUBJECTS = {
    1 => "💎 Why Ruby? Update: Testimonials, New Features, and One more thing..."
  }.freeze

  def update(user, version:)
    @user = user
    @version = version
    @open_tracking_url = "https://whyruby.info/newsletter/open/#{@user.newsletter_open_token(version)}"
    mail(
      to: @user.email,
      subject: SUBJECTS[version] || "Why Ruby? Update",
      template_name: "update_v#{version}"
    )
  end
end
