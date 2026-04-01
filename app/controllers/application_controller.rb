class ApplicationController < ActionController::Base
  rate_limit to: 100, within: 1.minute, name: "global"

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_user
  before_action :set_locale
  before_action :set_current_team, if: :team_scoped_request?

  private

  # ── Session-based authentication ──

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def user_signed_in?
    current_user.present?
  end
  helper_method :user_signed_in?

  def sign_in(user)
    reset_session
    session[:user_id] = user.id
    @current_user = user
  end

  def sign_out(_user = nil)
    reset_session
    @current_user = nil
  end

  def authenticate_user!
    unless user_signed_in?
      session[:return_to] = request.original_url if request.get?
      redirect_to github_auth_with_return_path, alert: "Please sign in with GitHub to continue."
    end
  end

  # ── Current attributes ──

  def set_current_user
    Current.user = current_user if defined?(Current) && Current.respond_to?(:user=)
  end

  # ── Locale ──

  def set_locale
    I18n.locale = detect_locale
  end

  def detect_locale
    if current_user&.respond_to?(:locale) && current_user.locale.present?
      return current_user.locale.to_sym
    end

    if request.headers["Accept-Language"] && defined?(Language)
      accepted = parse_accept_language(request.headers["Accept-Language"])
      enabled = Language.enabled_codes

      accepted.each do |code|
        return code.to_sym if enabled.include?(code)
      end
    end

    I18n.default_locale
  end

  def detected_locale
    I18n.locale
  end
  helper_method :detected_locale

  # ── Team scoping ──

  def set_current_team
    return unless current_user

    @current_team = current_user.teams.find_by(slug: params[:team_slug])

    unless @current_team
      redirect_to teams_path, alert: t("controllers.application.team_not_found", default: "Team not found")
      return
    end

    Current.team = @current_team if defined?(Current) && Current.respond_to?(:team=)
    Current.membership = current_user.membership_for(@current_team) if defined?(Current) && Current.respond_to?(:membership=)
  end

  def team_scoped_request?
    params[:team_slug].present?
  end

  def current_team
    @current_team
  end
  helper_method :current_team

  def current_membership
    current_user&.membership_for(@current_team) if @current_team
  end
  helper_method :current_membership

  def current_admin
    @current_admin ||= Admin.find_by(id: session[:admin_id]) if session[:admin_id]
  end
  helper_method :current_admin

  def authenticate_admin!
    redirect_to root_path, alert: "Admin access required" unless current_user&.admin?
  end

  def require_team_admin!
    unless current_membership&.admin?
      redirect_to team_root_path(current_team), alert: t("controllers.application.admin_required", default: "Admin access required")
    end
  end

  def require_subscription!
    return unless current_team
    return if current_team.subscription_active?

    redirect_to team_pricing_path(current_team),
      alert: t("controllers.application.subscription_required", default: "Subscription required")
  end

  def parse_accept_language(header)
    header.to_s.split(",").filter_map { |entry|
      lang, quality = entry.strip.split(";")
      code = lang&.strip&.split("-")&.first&.downcase
      q = quality ? quality.strip.delete_prefix("q=").to_f : 1.0
      [ code, q ] if code.present?
    }.sort_by { |_, q| -q }.map(&:first).uniq
  end
end
