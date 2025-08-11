class UsersController < ApplicationController
  def index
    @users = User.includes(:posts, :comments)

    # Apply filters if present
    if params[:location].present?
      @users = @users.where(location: params[:location])
      @filter_location = params[:location]
    end

    if params[:company].present?
      @users = @users.where(company: params[:company])
      @filter_company = params[:company]
    end

    @users = @users.order(published_posts_count: :desc, published_comments_count: :desc)
                   .page(params[:page])
                   .per(20)
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
