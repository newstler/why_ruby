class UserSettings::VisibilitiesController < ApplicationController
  before_action :authenticate_user!

  def update
    current_user.update!(public: !current_user.public)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("profile_settings_desktop", partial: "users/profile_settings", locals: { user: current_user, wrapper_id: "profile_settings_desktop" }),
          turbo_stream.replace("profile_settings_mobile", partial: "users/profile_settings", locals: { user: current_user, wrapper_id: "profile_settings_mobile" })
        ]
      end
      format.html { redirect_to user_path(current_user) }
    end
  end
end
