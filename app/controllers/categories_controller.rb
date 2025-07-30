class CategoriesController < ApplicationController
  def show
    @category = Category.find(params[:id])
    @posts = @category.posts.published.includes(:user, :tags)
                         .page(params[:page])
  end
end 