class TagsController < ApplicationController
  def show
    @tag = Tag.friendly.find(params[:id])
    @posts = @tag.posts.published.includes(:user, :category)
                    .page(params[:page])
  end
end 