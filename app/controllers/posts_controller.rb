class PostsController < ApplicationController
  before_action :authenticate_user!, except: [ :show, :success_stories, :image ]
  before_action :set_post, only: [ :show, :edit, :update, :destroy, :image ]
  before_action :authorize_user!, only: [ :edit, :update, :destroy ]

  def index
    @posts = current_user.posts
                         .includes(:category, :tags, :comments)
                         .page(params[:page])
                         .per(20)
  end

  def success_stories
    @posts = Post.success_stories
                 .published
                 .includes(:user, :comments)
                 .page(params[:page])
                 .per(20)
  end

  def show
    @comments = @post.comments.published.includes(:user).order(created_at: :asc)
  end

  # Serve generated PNG images for success stories
  def image
    if @post.success_story? && @post.logo_png_base64.present?
      # Success story - serve the generated PNG
      data = @post.logo_png_base64.match(/^data:image\/png;base64,(.+)$/)[1]
      image_data = Base64.decode64(data)

      # Use ETag based on post's updated_at to allow caching but invalidate on changes
      # This way browsers cache the image but revalidate when the post is updated
      fresh_when(etag: @post, last_modified: @post.updated_at, public: true)

      send_data image_data,
                type: "image/png",
                disposition: "inline",
                filename: "#{@post.slug}.png"
    else
      # No image available
      head :not_found
    end
  end



  def new
    @post = current_user.posts.build
  end

  def create
    @post = current_user.posts.build(post_params.except(:tag_names))
    clean_post_params
    process_tags

    if @post.save
      redirect_to @post, notice: "Post was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    process_tags

    # Clean params before update
    cleaned_params = post_params.except(:tag_names)
    cleaned_params[:category_id] = nil if cleaned_params[:category_id] == "" && @post.success_story?

    if @post.update(cleaned_params)
      redirect_to @post, notice: "Post was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Store the user before destroying the post
    @user = @post.user
    @post.destroy!

    # Reload user to get updated counter cache
    @user.reload if @user

    respond_to do |format|
      format.html {
        # Regular HTML request (from post show page with Turbo disabled)
        redirect_to "#{user_path(current_user)}#posts", notice: "Post was successfully deleted.", status: :see_other
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

    # Only allow viewing unpublished posts by their owner or admin
    if !@post.published? && (!user_signed_in? || (current_user != @post.user && !current_user.admin?))
      redirect_to root_path, alert: "This post is not published yet."
    end
  end



  def normalize_url_for_checking(url)
    return nil unless url.present?

    # Strip and remove trailing slashes
    normalized = url.strip.gsub(/\/+$/, "")

    # Convert http to https for common domains
    if normalized.match?(/^http:\/\/(www\.)?(github\.com|twitter\.com|youtube\.com|linkedin\.com|stackoverflow\.com)/i)
      normalized = normalized.sub(/^http:/, "https:")
    end

    normalized
  end

  def authorize_user!
    unless @post.user == current_user || current_user.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end

  def post_params
    params.require(:post).permit(:title, :content, :url, :summary, :category_id, :title_image_url, :published, :tag_names, :post_type, :logo_svg, tag_ids: [])
  end

  def clean_post_params
    # Convert empty string category_id to nil for success stories
    if @post.post_type == "success_story" && @post.category_id == ""
      @post.category_id = nil
    end
  end

  def process_tags
    return unless params[:post][:tag_names]

    tag_names = params[:post][:tag_names].to_s.split(",").map(&:strip).reject(&:blank?).uniq

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
