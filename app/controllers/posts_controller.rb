class PostsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :authorize_user!, only: [:edit, :update, :destroy]
  
  def index
    @posts = current_user.posts
                         .includes(:category, :tags, :comments)
                         .page(params[:page])
                         .per(20)
  end
  
  def show
    @comments = @post.comments.published.includes(:user).order(created_at: :asc)
  end
  
  def new
    @post = current_user.posts.build
  end
  
  def create
    @post = current_user.posts.build(post_params.except(:tag_names))
    process_tags
    
    if @post.save
      redirect_to @post, notice: 'Post was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    process_tags
    
    if @post.update(post_params.except(:tag_names))
      redirect_to @post, notice: 'Post was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @post.destroy!
    
    respond_to do |format|
      format.html { 
        # Regular HTML request (from post show page with Turbo disabled)
        redirect_to "#{user_path(current_user)}#posts", notice: 'Post was successfully deleted.', status: :see_other 
      }
      format.turbo_stream {
        # Turbo request (from tile grid)
        render :destroy
      }
    end
  end
  
  def preview
    html = helpers.markdown_to_html(params[:content])
    render json: { html: html }
  end
  
  def fetch_metadata
    url = params[:url]
    
    # Normalize URL for duplicate checking
    normalized_url = normalize_url_for_checking(url)
    
    # Check for existing post
    existing_post = Post.where(url: normalized_url).first
    if existing_post
      render json: { 
        success: false, 
        duplicate: true, 
        existing_post: {
          id: existing_post.id,
          title: existing_post.title,
          url: post_path(existing_post)
        }
      }
      return
    end
    
    begin
      page = MetaInspector.new(url)
      
      metadata = {
        title: page.best_title || page.title,
        summary: page.best_description || page.description,
        image_url: page.images.best || page.images.first
      }
      
      render json: { success: true, metadata: metadata }
    rescue => e
      render json: { success: false, error: e.message }
    end
  end
  
  def check_duplicate_url
    url = params[:url]
    normalized_url = normalize_url_for_checking(url)
    
    existing_post = Post.where(url: normalized_url).where.not(id: params[:exclude_id]).first
    
    if existing_post
      render json: { 
        duplicate: true, 
        existing_post: {
          id: existing_post.id,
          title: existing_post.title,
          url: post_path(existing_post)
        }
      }
    else
      render json: { duplicate: false }
    end
  end

  private
  
  def set_post
    @post = Post.includes(:tags).friendly.find(params[:id])
  end
  
  def normalize_url_for_checking(url)
    return nil unless url.present?
    
    # Strip and remove trailing slashes
    normalized = url.strip.gsub(/\/+$/, '')
    
    # Convert http to https for common domains
    if normalized.match?(/^http:\/\/(www\.)?(github\.com|twitter\.com|youtube\.com|linkedin\.com|stackoverflow\.com)/i)
      normalized = normalized.sub(/^http:/, 'https:')
    end
    
    normalized
  end
  
  def authorize_user!
    unless @post.user == current_user || current_user.admin?
      redirect_to root_path, alert: 'Not authorized'
    end
  end
  
  def post_params
    params.require(:post).permit(:title, :content, :url, :summary, :category_id, :title_image_url, :published, :tag_names, tag_ids: [])
  end
  
  def process_tags
    return unless params[:post][:tag_names]
    
    tag_names = params[:post][:tag_names].to_s.split(',').map(&:strip).reject(&:blank?).uniq
    
    if tag_names.empty?
      @post.tags = []
    else
      tags = []
      tag_names.each do |name|
        # Find or create tag by name
        tag = Tag.find_or_create_by(name: name)
        tags << tag
      end
      @post.tags = tags
    end
  end
end 