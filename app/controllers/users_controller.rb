class UsersController < ApplicationController
  def index
    @users = User.includes(:posts, :comments)
    @total_users_count = User.count

    # Apply filters if present
    if params[:location].present?
      @users = @users.where(location: params[:location].strip)
      @filter_location = params[:location].strip
    end

    if params[:company].present?
      @users = @users.where(company: params[:company].strip)
      @filter_company = params[:company].strip
    end

    # Sorting
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

    direction = @dir.to_sym

    @users = case @sort
    when "new"
               @users.order(created_at: direction)
    when "old"
               @users.order(created_at: direction)
    when "projects"
               @users.order(github_repos_count: direction)
    when "posts"
               @users.order(published_posts_count: direction)
    when "comments"
               @users.order(published_comments_count: direction)
    when "stars"
               @users.order(github_stars_sum: direction)
    when "az"
               # Toggle A–Z vs Z–A using direction
               @users.order(Arel.sql("COALESCE(name, username) #{direction == :asc ? 'ASC' : 'DESC'}"))
    else
               @users.order(github_stars_sum: direction, published_posts_count: direction, github_repos_count: direction)
    end

    @users = @users.page(params[:page]).per(20)
  end

  def show
    @user = User.friendly.find(params[:id])

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
    @ruby_repos = @user.ruby_repositories
  end
end
