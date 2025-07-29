class TagsController < ApplicationController
  def show
    @tag = Tag.find(params[:id])
    @contents = @tag.contents.published.includes(:user, :category)
                    .page(params[:page])
  end
end 