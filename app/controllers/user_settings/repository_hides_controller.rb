class UserSettings::RepositoryHidesController < ApplicationController
  before_action :authenticate_user!

  def create
    repo_url = params.expect(:repo_url)
    current_user.hide_repository!(repo_url)
    render_projects_update
  end

  def destroy
    repo_url = params.expect(:repo_url)
    current_user.unhide_repository!(repo_url)
    render_projects_update
  end

  private

  def render_projects_update
    current_user.reload
    @ruby_repos = current_user.visible_ruby_repositories
    @hidden_repos = current_user.hidden_ruby_repositories

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("projects_panel", partial: "users/projects_panel", locals: { ruby_repos: @ruby_repos, hidden_repos: @hidden_repos, user: current_user }),
          turbo_stream.update("projects_count", html: @ruby_repos.size.to_s),
          turbo_stream.replace("profile_stars", partial: "users/profile_stars", locals: { user: current_user })
        ]
      end
      format.html { redirect_to user_path(current_user) }
    end
  end
end
