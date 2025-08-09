class HomeController < ApplicationController
  def index
    @pinned_posts = Post.published.pinned.includes(:user, :category, :tags)
    @posts = Post.published.includes(:user, :category, :tags)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
  end
end
