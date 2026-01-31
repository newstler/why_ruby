class Users::SessionsController < Devise::SessionsController
  COMMUNITY_HOST = "rubycommunity.org".freeze
  PRIMARY_HOST = "whyruby.info".freeze

  def github_auth
    # Store the return_to path in session
    session[:return_to] = params[:return_to] if params[:return_to].present?

    # If on community domain, redirect through primary domain for OAuth (passing host via params since cookies don't cross domains)
    if request.host == COMMUNITY_HOST
      redirect_to "https://#{PRIMARY_HOST}/sign_in_github?from_host=#{COMMUNITY_HOST}", allow_other_host: true
    elsif params[:from_host] == COMMUNITY_HOST
      # Came from community domain via redirect - store in session now that we're on primary domain
      session[:return_to_host] = COMMUNITY_HOST
      redirect_to user_github_omniauth_authorize_path, allow_other_host: true
    else
      redirect_to user_github_omniauth_authorize_path, allow_other_host: true
    end
  end

  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    respond_to_on_destroy
  end

  private

  def respond_to_on_destroy
    if request.host == COMMUNITY_HOST
      redirect_to "https://#{COMMUNITY_HOST}/community"
    else
      redirect_to root_path
    end
  end
end
