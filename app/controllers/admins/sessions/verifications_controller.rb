class Admins::Sessions::VerificationsController < ApplicationController
  rate_limit to: 5, within: 5.minutes, name: "admin_sessions/verify",
    with: -> { redirect_to new_admins_session_path, alert: t("controllers.admins.sessions.rate_limit.verify") }

  layout "admin_auth"

  def show
    admin = Admin.find_signed!(params[:token], purpose: :magic_link)
    session[:admin_id] = admin.id

    redirect_to "/madmin", notice: t("controllers.admins.sessions.verify.notice")
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_admins_session_path, alert: t("controllers.admins.sessions.verify.alert")
  end
end
