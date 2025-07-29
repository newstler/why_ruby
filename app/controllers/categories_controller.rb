class CategoriesController < ApplicationController
  def show
    @category = Category.find(params[:id])
    @contents = @category.contents.published.includes(:user, :tags)
                         .page(params[:page])
  end
end 