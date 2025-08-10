class HomeController < ApplicationController
  def index
    @pinned_posts = Post.published.pinned.includes(:user, :category, :tags)
                          .reorder(:pin_position)
    @posts = Post.published.includes(:user, :category, :tags)
                      .page(params[:page])
                      .per(20)
  end
end
