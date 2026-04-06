class Tags::SearchesController < ApplicationController
  def show
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
