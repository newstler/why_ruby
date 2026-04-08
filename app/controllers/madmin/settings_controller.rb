module Madmin
  class SettingsController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
    end

    def edit
      @setting = Setting.instance
    end

    def update
      @setting = Setting.instance

      if @setting.update(setting_params)
        redirect_to main_app.madmin_settings_path, notice: t("controllers.madmin.settings.update.notice")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def setting_params
      params.require(:setting).permit(
        :github_api_token,
        :github_rubycommunity_client_id,
        :github_rubycommunity_client_secret,
        :github_whyruby_client_id,
        :github_whyruby_client_secret,
        :litestream_replica_bucket,
        :litestream_replica_key_id,
        :litestream_replica_access_key,
        :public_chats,
        :stripe_secret_key,
        :stripe_publishable_key,
        :stripe_webhook_secret,
        :trial_days,
      )
    end
  end
end
