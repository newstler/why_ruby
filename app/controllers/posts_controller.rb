class PostsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :authorize_user!, only: [:edit, :update, :destroy]
  
  def index
    @pinned_posts = Post.published.pinned.includes(:user, :category, :tags)
    @posts = Post.published.includes(:user, :category, :tags)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
  end
  
  def show
    @comments = @post.comments.published.includes(:user).recent
  end
  
  def new
    @post = current_user.posts.build
  end
  
  def create
    @post = current_user.posts.build(post_params)
    
    if @post.save
      redirect_to @post, notice: 'Post was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @post.update(post_params)
      redirect_to @post, notice: 'Post was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @post.update!(archived: true)
    redirect_to posts_url, notice: 'Post was successfully deleted.'
  end
  
  def preview
    html = helpers.markdown_to_html(params[:content])
    render json: { html: html }
  end
  
  private
  
  def set_post
    @post = Post.find(params[:id])
  end
  
  def authorize_user!
    unless @post.user == current_user || current_user.admin?
      redirect_to root_path, alert: 'Not authorized'
    end
  end
  
  def post_params
    params.require(:post).permit(:title, :content, :url, :category_id, :title_image_url, :published, tag_ids: [])
  end
end 