class TagsController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @posts = @tag.posts.published.includes(:user, :category)
                    .page(params[:page])
  end
end 