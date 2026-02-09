class Users::SessionsController < Devise::SessionsController
  def github_auth
    # Store the return_to path in session
    session[:return_to] = params[:return_to] if params[:return_to].present?

    # Detect if signing in from community pages (to redirect to profile after sign in)
    session[:from_community] = from_community_page?

    redirect_to user_github_omniauth_authorize_path, allow_other_host: true
  end

  def destroy
    domains = Rails.application.config.x.domains

    # Determine where to redirect after sign out
    # Community pages -> community index, otherwise -> home
    return_to_path = from_community_page? ? users_path : "/"

    other_host = (request.host == domains.community) ? domains.primary : domains.community
    current_host = request.host

    # Generate token for cross-domain sign out
    token = current_user&.generate_cross_domain_token!

    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out

    if Rails.env.production? && token
      # Sign out on other domain, then come back to this domain
      # On community domain, return to root "/"; on primary domain, redirect to community domain root
      prod_return_path = (current_host == domains.community) ? "/" : "https://#{domains.community}/"
      final_destination = from_community_page? ? prod_return_path : "https://#{current_host}/"
      redirect_to "https://#{other_host}/auth/sign_out_receive?token=#{token}&return_to=#{CGI.escape(final_destination)}", allow_other_host: true
    else
      redirect_to return_to_path
    end
  end

  private

  def from_community_page?
    domains = Rails.application.config.x.domains
    # Check if on community domain
    return true if request.host == domains.community

    # Check if current path or referer is a community path
    return true if request.path.start_with?("/community")

    # Check referer for community pages (for sign-in button clicks)
    if request.referer.present?
      referer_uri = URI.parse(request.referer) rescue nil
      return true if referer_uri && (referer_uri.host == domains.community || referer_uri.path.start_with?("/community"))
    end

    false
  end
end
