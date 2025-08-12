class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def after_sign_in_path_for(resource)
    # Redirect to user's profile after sign in
    if resource.is_a?(User)
      user_path(resource)
    else
      super
    end
  end
end
