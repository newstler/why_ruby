class ContentsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_content, only: [:show, :edit, :update, :destroy]
  before_action :authorize_user!, only: [:edit, :update, :destroy]
  
  def index
    @pinned_contents = Content.published.pinned.includes(:user, :category, :tags)
    @contents = Content.published.includes(:user, :category, :tags)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
    @categories = Category.ordered
  end
  
  def show
    @comments = @content.comments.published.includes(:user).recent
  end
  
  def new
    @content = current_user.contents.build
  end
  
  def create
    @content = current_user.contents.build(content_params)
    
    if @content.save
      redirect_to @content, notice: 'Content was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @content.update(content_params)
      redirect_to @content, notice: 'Content was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @content.update!(archived: true)
    redirect_to contents_url, notice: 'Content was successfully deleted.'
  end
  
  private
  
  def set_content
    @content = Content.find(params[:id])
  end
  
  def authorize_user!
    unless @content.user == current_user || current_user.admin?
      redirect_to root_path, alert: 'Not authorized'
    end
  end
  
  def content_params
    params.require(:content).permit(:title, :content, :url, :category_id, :title_image_url, :published, tag_ids: [])
  end
end 