module Madmin
  module Settings
    class AiModelsController < Madmin::ApplicationController
      def show
        @setting = Setting.instance
      end

      def edit
        @setting = Setting.instance
      end

      def update
        @setting = Setting.instance

        if @setting.update(setting_params)
          redirect_to main_app.madmin_settings_ai_models_path, notice: t("controllers.madmin.settings.ai_models.update.notice")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def setting_params
        params.require(:setting).permit(
          :default_ai_model,
          :summary_model,
          :testimonial_model,
          :translation_model,
          :validation_model,
        )
      end
    end
  end
end
