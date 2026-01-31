class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :github

  def github
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in @user, event: :authentication
      set_flash_message(:notice, :success, kind: "GitHub") if is_navigational_format?
      redirect_to after_sign_in_path, allow_other_host: true
    else
      session["devise.github_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to root_path, alert: "Authentication failed."
  end

  private

  def after_sign_in_path
    # Get the original page user was on (stored in session before OAuth)
    return_to = session.delete(:return_to)
    session.delete(:from_community) # Clean up, not used anymore

    # Determine final destination
    # If specific return_to is set, use it; otherwise go to user profile
    final_destination = return_to.presence || user_profile_path

    # In production, sync session to other domain first, then return to original page
    if Rails.env.production?
      domains = Rails.application.config.x.domains
      other_host = (request.host == domains.community) ? domains.primary : domains.community
      current_host = request.host
      token = @user.generate_cross_domain_token!

      # Build full URL for final destination
      final_url = "https://#{current_host}#{final_destination}"

      # Redirect to other domain to sync session, passing final destination
      "https://#{other_host}/auth/receive?token=#{token}&return_to=#{CGI.escape(final_url)}"
    else
      final_destination
    end
  end

  def user_profile_path
    # In development: /community/:username
    # In production on community domain: /:username
    domains = Rails.application.config.x.domains
    if Rails.env.production? && request.host == domains.community
      "/#{@user.to_param}"
    else
      "/community/#{@user.to_param}"
    end
  end
end
