class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @posts = @user.posts.published.includes(:category, :tags)
                     .page(params[:page])
  end
end 