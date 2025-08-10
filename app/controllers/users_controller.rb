class UsersController < ApplicationController
  def index
    @users = User.includes(:posts, :comments)
                 .order(published_posts_count: :desc, published_comments_count: :desc)
                 .page(params[:page])
                 .per(20)
  end
  
  def show
    @user = User.friendly.find(params[:id])
    
    # Load posts with pagination support
    @posts = @user.posts.published.includes(:category, :tags)
                     .page(params[:page])
    
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