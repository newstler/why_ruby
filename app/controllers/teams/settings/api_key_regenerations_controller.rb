class Teams::Settings::ApiKeyRegenerationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def create
    current_team.regenerate_api_key!
    redirect_to team_settings_path(current_team), notice: t("controllers.teams.settings.regenerate_api_key.notice")
  end
end
