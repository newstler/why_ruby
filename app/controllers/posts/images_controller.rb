class Posts::ImagesController < ApplicationController
  before_action :set_post

  def show
    if @post.featured_image.attached?
      og_blob = @post.image_variant(:og)

      if og_blob
        send_data og_blob.download,
                  type: "image/webp",
                  disposition: "inline"
      else
        send_data @post.featured_image.download,
                  type: "image/webp",
                  disposition: "inline"
      end
    else
      send_file Rails.root.join("public", "og-image.webp"),
                type: "image/webp",
                disposition: "inline"
    end
  end

  private

  def set_post
    if params[:category_id]
      @category = Category.friendly.find(params[:category_id])
      @post = @category.posts.friendly.find(params[:post_id] || params[:id])
    else
      @post = Post.friendly.find(params[:post_id] || params[:id])
    end
  end
end
