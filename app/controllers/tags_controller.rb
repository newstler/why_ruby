class TagsController < ApplicationController
  def show
    @tag = Tag.friendly.find(params[:id])
    @posts = @tag.posts.published.includes(:user, :category)
                    .page(params[:page])
  end

  def search
    query = params[:q].to_s.strip.downcase

    if query.present?
      tags = Tag.where("LOWER(name) LIKE ?", "%#{query}%")
                .order(:name)
                .limit(10)

      render json: tags.map { |tag| { id: tag.id, name: tag.name } }
    else
      render json: []
    end
  end
end
