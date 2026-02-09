class AuthController < ApplicationController
  # Receives cross-domain auth token and creates local session
  # Then redirects to the final destination (which may be on another domain)
  def receive
    token = params[:token]
    destination = safe_return_to

    user = User.authenticate_cross_domain_token(token)
    if user
      sign_in(user)
      redirect_to destination, allow_other_host: true
    elsif user_signed_in?
      # User is already signed in on this domain, just redirect
      redirect_to destination, allow_other_host: true
    else
      redirect_to root_path, alert: "Session sync failed. Please sign in again."
    end
  end

  # Cross-domain sign out - signs out here, then redirects to final destination
  def sign_out_receive
    token = params[:token]
    destination = safe_return_to

    user = User.authenticate_cross_domain_token(token)
    sign_out(user) if user && user_signed_in? && current_user == user

    redirect_to destination, allow_other_host: true
  end

  private

  def safe_return_to
    url = params[:return_to]
    return root_url if url.blank?

    uri = URI.parse(url)
    return root_url unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    domains = Rails.application.config.x.domains
    allowed = [ domains.primary, domains.community, "localhost" ]
    allowed.any? { |d| uri.host&.end_with?(d) } ? url : root_url
  rescue URI::InvalidURIError
    root_url
  end
end
