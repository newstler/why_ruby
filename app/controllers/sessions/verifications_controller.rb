class Sessions::VerificationsController < ApplicationController
  rate_limit to: 10, within: 5.minutes, name: "sessions/verify",
    with: -> { redirect_to new_session_path, alert: t("controllers.sessions.rate_limit.verify") }

  def show
    user = User.find_signed!(params[:token], purpose: :magic_link)

    if params[:team].present?
      handle_team_invitation(user, params[:team], params[:invited_by])
    end

    session[:user_id] = user.id
    save_locale_from_header(user) if user.locale.nil?

    if user.onboarded?
      redirect_to after_login_path(user, params[:team]), notice: t("controllers.sessions.verify.notice", name: user.name)
    else
      ensure_team_exists(user, params[:team])
      redirect_to onboarding_path
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: t("controllers.sessions.verify.alert")
  end

  private

  def handle_team_invitation(user, team_slug, invited_by_id)
    team = Team.find_by(slug: team_slug)
    return unless team

    invited_by = User.find_by(id: invited_by_id)

    unless user.member_of?(team)
      user.memberships.create!(team: team, invited_by: invited_by, role: "member")
    end
  end

  def after_login_path(user, invited_team_slug = nil)
    if invited_team_slug.present?
      team = Team.find_by(slug: invited_team_slug)
      return team_root_path(team) if team && user.member_of?(team)
    end

    teams = user.teams

    case teams.size
    when 0
      team = create_personal_team(user)
      team_root_path(team)
    when 1
      team_root_path(teams.first)
    else
      teams_path
    end
  end

  def ensure_team_exists(user, invited_team_slug = nil)
    return if user.teams.exists?

    create_personal_team(user)
  end

  def create_personal_team(user)
    team = Team.create!(name: "#{user.name || user.email.split('@').first}'s Team")
    team.memberships.create!(user: user, role: "owner")
    team
  end

  def save_locale_from_header(user)
    return unless request.headers["Accept-Language"]

    accepted = parse_accept_language(request.headers["Accept-Language"])
    enabled = Language.enabled_codes

    accepted.each do |code|
      if enabled.include?(code)
        user.update_column(:locale, code)
        return
      end
    end
  end
end
