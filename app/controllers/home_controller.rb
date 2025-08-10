class HomeController < ApplicationController
  def index
    @pinned_posts = Post.published.pinned
                          .where.not(post_type: "success_story")
                          .includes(:user, :category, :tags)
                          .reorder(:pin_position)
    @posts = Post.published
                      .where.not(post_type: "success_story")
                      .includes(:user, :category, :tags)
                      .page(params[:page])
                      .per(20)
    @success_stories = Post.success_stories
                           .published
                           .includes(:user)
                           .order(created_at: :desc)
  end
end
