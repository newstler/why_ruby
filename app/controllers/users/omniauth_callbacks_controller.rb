class Users::OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :github

  def github
    auth = request.env["omniauth.auth"]
    @user = User.from_omniauth(auth)

    if @user.persisted?
      sign_in @user
      redirect_to after_sign_in_path, allow_other_host: true
    else
      redirect_to root_path, alert: "Authentication failed."
    end
  end

  def failure
    redirect_to root_path, alert: "Authentication failed."
  end

  private

  def after_sign_in_path
    # Get the original page user was on (stored in session before OAuth)
    return_to = session.delete(:return_to)

    # Determine final destination
    final_destination = return_to.presence || user_profile_path

    # In production, sync session to other domain first, then return to original page
    if Rails.env.production?
      domains = Rails.application.config.x.domains
      other_host = (request.host == domains.community) ? domains.primary : domains.community
      current_host = request.host
      token = @user.generate_cross_domain_token!

      final_url = final_destination.start_with?("https://") ? final_destination : "https://#{current_host}#{final_destination}"

      "https://#{other_host}/auth/receive?token=#{token}&return_to=#{CGI.escape(final_url)}"
    else
      final_destination
    end
  end

  def user_profile_path
    domains = Rails.application.config.x.domains
    if Rails.env.production?
      "https://#{domains.community}/#{@user.to_param}"
    else
      "/community/#{@user.to_param}"
    end
  end
end
