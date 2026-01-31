class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :github

  COMMUNITY_HOST = "rubycommunity.org".freeze

  def github
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in @user, event: :authentication
      set_flash_message(:notice, :success, kind: "GitHub") if is_navigational_format?
      redirect_to after_sign_in_path
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
    return_to_host = session.delete(:return_to_host)
    return_to_path = session.delete(:return_to)

    if return_to_host == COMMUNITY_HOST
      "https://#{COMMUNITY_HOST}#{return_to_path || '/community'}"
    elsif return_to_path.present?
      return_to_path
    else
      root_path
    end
  end
end
