class Users::SessionsController < Devise::SessionsController
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
