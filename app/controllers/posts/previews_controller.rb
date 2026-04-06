class Posts::PreviewsController < ApplicationController
  before_action :authenticate_user!

  def create
    html = helpers.markdown_to_html(params[:content])
    render json: { html: html }
  end
end
