class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @contents = @user.contents.published.includes(:category, :tags)
                     .page(params[:page])
  end
end 