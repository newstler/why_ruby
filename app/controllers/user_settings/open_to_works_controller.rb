class UserSettings::OpenToWorksController < ApplicationController
  before_action :authenticate_user!

  def update
    current_user.update!(open_to_work: !current_user.open_to_work)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("profile_settings_desktop", partial: "users/profile_settings", locals: { user: current_user, wrapper_id: "profile_settings_desktop" }),
          turbo_stream.replace("profile_settings_mobile", partial: "users/profile_settings", locals: { user: current_user, wrapper_id: "profile_settings_mobile" }),
          turbo_stream.replace("profile_avatar_desktop", partial: "users/profile_avatar", locals: { user: current_user, wrapper_id: "profile_avatar_desktop", size: "w-36 h-[130px]", text_size: "text-5xl" }),
          turbo_stream.replace("profile_avatar_mobile", partial: "users/profile_avatar", locals: { user: current_user, wrapper_id: "profile_avatar_mobile", size: "w-28 h-[100px]", text_size: "text-4xl" })
        ]
      end
      format.html { redirect_to user_path(current_user) }
    end
  end
end
