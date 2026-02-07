class UsersController < ApplicationController
  def index
    @users = User.visible
    @total_users_count = User.visible.count

    # Sorting - set up early so it can be applied to both main and other country users
    @sort = params[:sort].presence || "top"
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
      @users = @users.by_normalized_location(params[:location].strip)
      @filter_location = params[:location].strip

      # Extract country code and load users from other parts of the country
      @filter_country_code = @filter_location.split(", ").last if @filter_location.include?(", ")
      if @filter_country_code.present?
        @other_country_users = User.visible
                                   .from_country(@filter_country_code)
                                   .where.not(normalized_location: @filter_location)
        @other_country_users = apply_sorting(@other_country_users)
        @other_country_users = @other_country_users.page(params[:other_page]).per(20)
      end
    end

    if params[:company].present?
      @users = @users.where(company: params[:company].strip)
      @filter_company = params[:company].strip
    end

    @users = apply_sorting(@users)
    @users = @users.page(params[:page]).per(20)
  end

  def og_image
    @users = User.where(public: true)
                 .where.not(avatar_url: [ nil, "" ])
                 .order(Arel.sql("COALESCE(github_stars_sum, 0) + COALESCE(published_posts_count, 0) * 10 + COALESCE(published_comments_count, 0) DESC"))
    @total_users_count = User.visible.count
    render layout: false
  end

  def show
    @user = User.friendly.find(params[:id])

    # Handle non-public profiles (only owner can view)
    unless @user.public? || (user_signed_in? && current_user == @user)
      redirect_to users_path, alert: "This profile is private."
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
  end

  private

  def apply_sorting(scope)
    direction = @dir.to_sym

    case @sort
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
