class PostsController < ApplicationController
  before_action :authenticate_user!, except: [ :show ]
  before_action :set_post, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_user!, only: [ :edit, :update, :destroy ]

  def show
    @comments = @post.comments.published.includes(:user).order(created_at: :asc)
  end


  def new
    @post = current_user.posts.build
    @post.category_id = params[:category_id] if params[:category_id].present?
  end

  def create
    @post = current_user.posts.build(post_params.except(:tag_names, :metadata_image_url, :remove_featured_image))
    clean_post_params
    process_tags

    # Save the post first
    if @post.save
      # Then handle image attachment after post is saved
      if @post.link? && params[:post][:metadata_image_url].present?
        fetch_and_attach_image_from_url(params[:post][:metadata_image_url])
      end

      # Redirect to category page for link posts, post page for others
      if @post.link? && @post.category
        redirect_to category_path(@post.category), notice: "Link was successfully posted."
      else
        redirect_to post_path_for(@post), notice: "Post was successfully created."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    process_tags

    # Clean params before update
    cleaned_params = post_params.except(:tag_names, :metadata_image_url, :remove_featured_image)
    cleaned_params[:category_id] = nil if cleaned_params[:category_id] == "" && @post.success_story?

    # Determine if we have a new image being uploaded
    has_new_image = cleaned_params[:featured_image].present? ||
                   (@post.link? && params[:post][:metadata_image_url].present?)

    # If we have a new image, always purge the old one first (regardless of remove flag)
    if has_new_image && @post.featured_image.attached?
      @post.featured_image.purge
      @post.clear_image_variants!
    # Otherwise, check if we're just removing without replacement
    elsif params[:post][:remove_featured_image] == "1" && !has_new_image
      @post.featured_image.purge_later
      @post.clear_image_variants!
    end

    # Handle metadata image fetch for link posts
    if @post.link? && params[:post][:metadata_image_url].present?
      fetch_and_attach_image_from_url(params[:post][:metadata_image_url])
      # Remove from cleaned_params to avoid Rails trying to process it
      cleaned_params.delete(:featured_image)
    end

    if @post.update(cleaned_params)
      # Redirect to category page for link posts, post page for others
      if @post.link? && @post.category
        redirect_to category_path(@post.category), notice: "Link was successfully updated."
      else
        redirect_to post_path_for(@post), notice: "Post was successfully updated."
      end
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

  private

  def fetch_and_attach_image_from_url(url)
    return if url.blank?
    @post.attach_image_from_url!(url)
  end

  def set_post
    # Handle category/post route
    if params[:category_id]
      @category = Category.friendly.find(params[:category_id])
      @post = @category.posts.includes(:tags, :user, :category).friendly.find(params[:id])
    # Handle direct post access (for edit, destroy, etc.)
    else
      @post = Post.includes(:tags, :user, :category).friendly.find(params[:id])
    end

    # Only allow viewing unpublished posts by their owner or admin
    if !@post.published? && (!user_signed_in? || (current_user != @post.user && !current_user.admin?))
      redirect_to root_path, alert: "This post is not published yet."
    end
  end



  def authorize_user!
    unless @post.user == current_user || current_user.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end

  def post_params
    params.require(:post).permit(:title, :content, :url, :summary, :category_id, :featured_image, :metadata_image_url, :remove_featured_image, :published, :tag_names, :post_type, :logo_svg, tag_ids: [])
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
    post_path(post.category, post)
  end
end
