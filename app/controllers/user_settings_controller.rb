class UserSettingsController < ApplicationController
  before_action :authenticate_user!

  def toggle_public
    current_user.update!(public: !current_user.public)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("profile_settings", partial: "users/profile_settings", locals: { user: current_user }) }
      format.html { redirect_to user_path(current_user) }
    end
  end

  def toggle_open_to_work
    current_user.update!(open_to_work: !current_user.open_to_work)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("profile_settings", partial: "users/profile_settings", locals: { user: current_user }),
          turbo_stream.replace("profile_avatar_desktop", partial: "users/profile_avatar", locals: { user: current_user, wrapper_id: "profile_avatar_desktop", size: "w-36 h-[130px]", text_size: "text-5xl" }),
          turbo_stream.replace("profile_avatar_mobile", partial: "users/profile_avatar", locals: { user: current_user, wrapper_id: "profile_avatar_mobile", size: "w-28 h-[100px]", text_size: "text-4xl" })
        ]
      end
      format.html { redirect_to user_path(current_user) }
    end
  end

  def hide_repo
    repo_url = params.expect(:repo_url)
    current_user.hide_repository!(repo_url)
    render_projects_update
  end

  def unhide_repo
    repo_url = params.expect(:repo_url)
    current_user.unhide_repository!(repo_url)
    render_projects_update
  end

  private

  def render_projects_update
    @ruby_repos = current_user.visible_ruby_repositories
    @hidden_repos = current_user.hidden_ruby_repositories

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("projects_panel", partial: "users/projects_panel", locals: { ruby_repos: @ruby_repos, hidden_repos: @hidden_repos, user: current_user }),
          turbo_stream.update("projects_count", html: @ruby_repos.size.to_s)
        ]
      end
      format.html { redirect_to user_path(current_user) }
    end
  end
end
