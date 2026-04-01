class Users::SessionsController < ApplicationController
  def github_auth
    # Store the return_to path in session
    session[:return_to] = params[:return_to] if params[:return_to].present?

    redirect_to "/auth/github", allow_other_host: true
  end

  def destroy
    domains = Rails.application.config.x.domains

    return_to_path = from_community_page? ? users_path : "/"

    other_host = (request.host == domains.community) ? domains.primary : domains.community
    current_host = request.host

    # Generate token for cross-domain sign out
    token = current_user&.generate_cross_domain_token!

    sign_out

    if Rails.env.production? && token
      prod_return_path = (current_host == domains.community) ? "/" : "https://#{domains.community}/"
      final_destination = from_community_page? ? prod_return_path : "https://#{current_host}/"
      redirect_to "https://#{other_host}/auth/sign_out_receive?token=#{token}&return_to=#{CGI.escape(final_destination)}", allow_other_host: true
    else
      redirect_to return_to_path, notice: "Signed out successfully."
    end
  end

  private

  def from_community_page?
    domains = Rails.application.config.x.domains
    return true if request.host == domains.community
    return true if request.path.start_with?("/community")

    if request.referer.present?
      referer_uri = URI.parse(request.referer) rescue nil
      return true if referer_uri && (referer_uri.host == domains.community || referer_uri.path.start_with?("/community"))
    end

    false
  end
end
