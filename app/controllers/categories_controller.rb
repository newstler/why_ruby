class CategoriesController < ApplicationController
  def show
    @category = Category.friendly.find(params[:id])

    # Handle success stories category specially if needed
    if @category.is_success_story?
      @posts = @category.posts.published.includes(:user, :tags, featured_image_attachment: :blob)
                           .page(params[:page])
      render "posts/success_stories"
    else
      @posts = @category.posts.published.includes(:user, :tags)
                           .page(params[:page])
    end
  end
end
