class UsersController < ApplicationController
  def index
    @users = User.visible

    # Sorting - set up early so it can be applied to both main and other country users
    @sort = params[:sort].presence || "trending"
    @dir  = params[:dir] == "asc" ? "asc" : "desc"

    # Normalize legacy/alternate sort params to our toggle model
    case @sort
    when "old"
      @sort = "new"
      @dir = "asc"
    when "za", "z-a"
      @sort = "az"
      @dir = "desc"
    end

    # Apply filters if present
    if params[:location].present?
      @filter_location = params[:location].strip
      is_country_only = !@filter_location.include?(", ")

      if is_country_only
        # Country-only filter: include all users from that country
        @users = @users.from_country(@filter_location)
      else
        @users = @users.by_normalized_location(@filter_location)

        # Extract country code and load users from other parts of the country
        @filter_country_code = @filter_location.split(", ").last
        @other_country_users = User.visible
                                   .from_country(@filter_country_code)
                                   .where.not(normalized_location: @filter_location)
        @other_country_users = apply_sorting(@other_country_users)
        @other_country_users = @other_country_users.page(params[:other_page]).per(20)
      end

      # Compute bounding box for map zoom-to-location
      filtered_users = is_country_only ? User.visible.from_country(@filter_location) : User.visible.by_normalized_location(@filter_location)
      geo_bounds = filtered_users
                       .where.not(latitude: nil, longitude: nil)
                       .pick(Arel.sql("MIN(latitude)"), Arel.sql("MAX(latitude)"),
                             Arel.sql("MIN(longitude)"), Arel.sql("MAX(longitude)"))
      if geo_bounds&.all?(&:present?)
        @filter_geo_bounds = { south: geo_bounds[0], north: geo_bounds[1], west: geo_bounds[2], east: geo_bounds[3] }
      end
    end

    if params[:company].present?
      @filter_company = params[:company].strip
      company_tokens = @filter_company.split(/\s+/)
      if company_tokens.size > 1
        @users = @users.where(company_tokens.map { "company LIKE ?" }.join(" OR "), *company_tokens.map { |t| "%#{User.sanitize_sql_like(t)}%" })
      else
        @users = @users.where(company: @filter_company)
      end
    end

    if params[:open_to_work] == "1"
      @users = @users.where(open_to_work: true)
      @filter_open_to_work = true
    end

    # Map bounds filtering
    if params[:south].present? && params[:north].present? && params[:west].present? && params[:east].present?
      south, north = params[:south].to_f, params[:north].to_f
      west, east = params[:west].to_f, params[:east].to_f
      @bounds = { south: south, north: north, west: west, east: east }

      @users = @users.where(latitude: south..north)
      if west <= east
        @users = @users.where(longitude: west..east)
      else
        @users = @users.where("longitude >= ? OR longitude <= ?", west, east)
      end
    end

    @total_users_count = @users.count

    @users = apply_sorting(@users)
    @users = @users.page(params[:page]).per(20)
  end

  def show
    @user = User.friendly.find(params[:id])

    # Handle non-public profiles (only owner can view)
    unless @user.public? || (user_signed_in? && current_user == @user)
      redirect_to helpers.community_index_path, alert: "This profile is private."
      return
    end

    # Load posts with pagination support
    # Show unpublished posts only to the owner
    @posts = if user_signed_in? && current_user == @user
               @user.posts.includes(:category, :tags)
                          .page(params[:page])
    else
               @user.posts.published.includes(:category, :tags)
                          .page(params[:page])
    end

    # Load all comments for display in the comments tab
    @comments = @user.comments.published.includes(:post)
                     .order(created_at: :desc)
                     .page(params[:page])

    # Keep recent comments for backward compatibility if needed
    @recent_comments = @user.comments.published.includes(:post)
                            .order(created_at: :desc)
                            .limit(9)

    # Get Ruby repositories for projects tab
    # Owner sees visible + hidden repos, others only see visible
    if user_signed_in? && current_user == @user
      @ruby_repos = @user.visible_ruby_repositories
      @hidden_repos = @user.hidden_ruby_repositories
    else
      @ruby_repos = @user.visible_ruby_repositories
      @hidden_repos = []
    end

    # Sort projects
    @project_sort = params[:project_sort].presence || "fresh"
    @project_dir = params[:project_dir] == "asc" ? "asc" : "desc"
    @ruby_repos = sort_projects(@ruby_repos)
  end

  private

  def sort_projects(repos)
    ascending = @project_dir == "asc"
    sorted = case @project_sort
    when "trending"
      repos.sort_by { |r| [ -r.stars_gained, -r.stars ] }
    when "stars"
      repos.sort_by { |r| -r.stars }
    when "az"
      repos.sort_by { |r| r.name.downcase }
    else # "fresh"
      repos
    end
    # az defaults to asc, others default to desc — reverse when opposite
    if @project_sort == "az"
      ascending ? sorted : sorted.reverse
    else
      ascending ? sorted.reverse : sorted
    end
  end

  def apply_sorting(scope)
    direction = @dir.to_sym

    case @sort
    when "trending"
      scope.order(stars_gained: direction, github_stars_sum: direction)
    when "new"
      scope.order(created_at: direction)
    when "old"
      scope.order(created_at: direction)
    when "projects"
      scope.order(github_repos_count: direction)
    when "posts"
      scope.order(published_posts_count: direction)
    when "comments"
      scope.order(published_comments_count: direction)
    when "stars"
      scope.order(github_stars_sum: direction)
    when "az"
      scope.order(Arel.sql("COALESCE(name, username) #{direction == :asc ? 'ASC' : 'DESC'}"))
    else
      scope.order(github_stars_sum: direction, published_posts_count: direction, github_repos_count: direction)
    end
  end
end
