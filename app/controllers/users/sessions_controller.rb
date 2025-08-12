class Users::SessionsController < Devise::SessionsController
  def github_auth
    # Store the return_to path in session
    session[:return_to] = params[:return_to] if params[:return_to].present?
    # Redirect to GitHub OAuth
    redirect_to user_github_omniauth_authorize_path, allow_other_host: true
  end

  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    respond_to_on_destroy
  end

  private

  def respond_to_on_destroy
    redirect_to root_path
  end
end
