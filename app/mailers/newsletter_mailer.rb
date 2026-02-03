# frozen_string_literal: true

class NewsletterMailer < ApplicationMailer
  def update(user, version:)
    @user = user
    @version = version
    mail(
      to: @user.email,
      subject: subject_for_version(version),
      template_name: "update_v#{version}"
    )
  end

  private

  def subject_for_version(version)
    {
      1 => "Why Ruby? — Now With Your Testimonials"
    }[version] || "Why Ruby? Update"
  end
end
