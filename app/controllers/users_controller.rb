class UsersController < ApplicationController
  def index
    @users = User.includes(:posts, :comments)
                 .order(published_posts_count: :desc, published_comments_count: :desc)
                 .page(params[:page])
                 .per(20)
  end
  
  def show
    @user = User.find(params[:id])
    @posts = @user.posts.published.includes(:category, :tags)
                     .page(params[:page])
    @recent_comments = @user.comments.published.includes(:post)
                            .order(created_at: :desc)
                            .limit(5)
  end
end 