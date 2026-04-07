class Posts::MetadataController < ApplicationController
  before_action :authenticate_user!

  def create
    url = params[:url]
    exclude_id = params[:exclude_id] || request.request_parameters[:exclude_id]

    normalized_url = normalize_url_for_checking(url)

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
      post = Post.new(url: url)
      result = post.fetch_metadata!

      metadata = {
        title: result[:title],
        summary: result[:description],
        image_url: result[:image_url]
      }

      render json: { success: true, metadata: metadata }
    rescue => e
      render json: { success: false, error: e.message }
    end
  end

  private

  def normalize_url_for_checking(url)
    return nil unless url.present?

    normalized = url.strip.gsub(/\/+$/, "")

    if normalized.match?(/^http:\/\/(www\.)?(github\.com|twitter\.com|youtube\.com|linkedin\.com|stackoverflow\.com)/i)
      normalized = normalized.sub(/^http:/, "https:")
    end

    normalized
  end

  def post_path_for(post)
    return root_path unless post.category
    post_path(post.category, post)
  end
end
