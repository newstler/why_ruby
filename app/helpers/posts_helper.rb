module PostsHelper
  # Distribute posts into columns for masonry-style layout
  # Returns an array of arrays, one per column
  def distribute_to_columns(posts, num_columns: 3)
    columns = Array.new(num_columns) { [] }
    posts.each_with_index { |post, i| columns[i % num_columns] << post }
    columns
  end

  def post_meta_title(post)
    if post.success_story?
      "#{post.title} Success Story"
    else
      post.title
    end
  end

  def post_meta_description(post)
    post.summary.presence || t("meta.default.summary")
  end

  def post_meta_keywords(post)
    categories_and_tags = [ post.category&.name, post.tags.map(&:name) ].compact.flatten.join(", ")
    categories_and_tags.presence ? "#{categories_and_tags}, Ruby, Rails" : t("meta.default.keywords")
  end

  def post_meta_image_url(post)
    if post.featured_image.attached?
      # Generate the resource-specific image URL with version parameter
      base_url = "#{request.base_url}/#{post.category.to_param}/#{post.to_param}/og-image.webp"
      "#{base_url}?v=#{post.updated_at.to_i}"
    else
      # Use the default versioned OG image
      versioned_og_image_url
    end
  end

  def post_meta_author(post)
    post.user&.display_name
  end
end
