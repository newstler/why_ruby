class PostsController < ApplicationController
  before_action :authenticate_user!, except: [ :show, :success_stories, :image ]
  before_action :set_post, only: [ :show, :edit, :update, :destroy, :image ]
  before_action :authorize_user!, only: [ :edit, :update, :destroy ]

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

  # Serve images directly for posts with stable URLs for social media
  def image
    if @post.featured_image.attached?
      # Serve the image directly from our custom URL
      # This provides a clean, stable URL for social media crawlers
      send_data @post.featured_image.download,
                type: @post.featured_image.content_type,
                disposition: "inline"
    else
      # Serve default OG image
      send_file Rails.root.join("public", "og-image.png"),
                type: "image/png",
                disposition: "inline"
    end
  end



  def new
    @post = current_user.posts.build
  end

  def create
    @post = current_user.posts.build(post_params.except(:tag_names, :metadata_image_url))
    clean_post_params
    process_tags

    # Fetch and attach image from metadata if it's a link post
    if @post.link? && params[:post][:metadata_image_url].present?
      fetch_and_attach_image_from_url(params[:post][:metadata_image_url])
    end

    if @post.save
      redirect_to post_path_for(@post), notice: "Post was successfully created."
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

    # Handle image removal if checkbox was checked
    if params[:post][:remove_featured_image] == "1"
      @post.featured_image.purge
    end

    if @post.update(cleaned_params)
      redirect_to post_path_for(@post), notice: "Post was successfully updated."
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
    exclude_id = params[:exclude_id] || request.request_parameters[:exclude_id]

    # Normalize URL for duplicate checking
    normalized_url = normalize_url_for_checking(url)

    # Check for existing post (excluding current post if editing)
    existing_post = Post.where(url: normalized_url)
    existing_post = existing_post.where.not(id: exclude_id) if exclude_id.present?
    existing_post = existing_post.first

    if existing_post
      render json: {
        success: false,
        duplicate: true,
        existing_post: {
          id: existing_post.id,
          title: existing_post.title,
          url: post_path_for(existing_post)
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

    # Handle exclude_id from both regular params and JSON body
    exclude_id = params[:exclude_id] || request.request_parameters[:exclude_id]

    existing_post = Post.where(url: normalized_url)
    existing_post = existing_post.where.not(id: exclude_id) if exclude_id.present?
    existing_post = existing_post.first

    if existing_post
      render json: {
        duplicate: true,
        existing_post: {
          id: existing_post.id,
          title: existing_post.title,
          url: post_path_for(existing_post)
        }
      }
    else
      render json: { duplicate: false }
    end
  end

  private

  def fetch_and_attach_image_from_url(url)
    return if url.blank? || @post.featured_image.attached?

    begin
      require "open-uri"
      require "net/http"

      # Download the image
      image_io = URI.open(url,
        "User-Agent" => "Ruby/#{RUBY_VERSION}",
        read_timeout: 10,
        open_timeout: 10
      )

      # Get filename from URL or use default
      filename = File.basename(URI.parse(url).path).presence || "image"
      # Add extension if missing
      unless filename.include?(".")
        content_type = image_io.meta["content-type"]
        extension = case content_type
        when /jpeg|jpg/i then ".jpg"
        when /png/i then ".png"
        when /gif/i then ".gif"
        when /webp/i then ".webp"
        else ".jpg"
        end
        filename += extension
      end

      # Attach the image
      @post.featured_image.attach(
        io: image_io,
        filename: filename
      )
    rescue => e
      Rails.logger.error "Failed to fetch image from URL #{url}: #{e.message}"
      # Don't fail the post creation if image fetch fails
    end
  end

  def set_post
    # Handle success story route
    if params[:success_story]
      @post = Post.success_stories.includes(:tags).friendly.find(params[:id])
    # Handle category/post route
    elsif params[:category_id]
      @category = Category.friendly.find(params[:category_id])
      @post = @category.posts.includes(:tags).friendly.find(params[:id])
    # Handle direct post access (for edit, destroy, etc.)
    else
      @post = Post.includes(:tags).friendly.find(params[:id])
    end

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
    params.require(:post).permit(:title, :content, :url, :summary, :category_id, :featured_image, :metadata_image_url, :published, :tag_names, :post_type, :logo_svg, tag_ids: [])
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

  def post_path_for(post)
    if post.success_story?
      success_story_path(post)
    elsif post.category
      post_path(post.category, post)
    else
      # Fallback for posts without category (shouldn't happen in normal flow)
      post_path("uncategorized", post)
    end
  end
end
