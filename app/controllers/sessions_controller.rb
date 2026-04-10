class SessionsController < ApplicationController
  # Short-term: prevent rapid-fire attempts
  rate_limit to: 5, within: 1.minute, name: "sessions/short", only: :create,
    with: -> { redirect_to new_session_path, alert: t("controllers.sessions.rate_limit.short") }

  # Long-term: prevent sustained attacks
  rate_limit to: 20, within: 1.hour, name: "sessions/long", only: :create,
    with: -> { redirect_to new_session_path, alert: t("controllers.sessions.rate_limit.long") }

  def new
    redirect_to root_path if current_user
  end

  def create
    email = params.expect(session: :email)[:email]
    user = User.find_by(email: email)

    # Create user if doesn't exist (first magic link creates the account)
    # Name is collected during onboarding after first login
    user ||= User.create!(email: email)

    # Send magic link
    UserMailer.magic_link(user).deliver_later

    redirect_to new_session_path, notice: t("controllers.sessions.create.notice")
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: t("controllers.sessions.destroy.notice")
  end
end
