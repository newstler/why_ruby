module PostsHelper
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
    categories_and_tags = [ post.category&.name, post.tags.pluck(:name) ].compact.flatten.join(", ")
    categories_and_tags.presence ? "#{categories_and_tags}, Ruby, Rails" : t("meta.default.keywords")
  end

  def post_meta_image_url(post)
    if post.featured_image.attached?
      if post.success_story?
        "#{request.base_url}/success-stories/#{post.to_param}/og-image.png"
      elsif post.category
        "#{request.base_url}/#{post.category.to_param}/#{post.to_param}/og-image.png"
      else
        # Fallback for posts without category (shouldn't happen normally)
        "#{request.base_url}/uncategorized/#{post.to_param}/og-image.png"
      end
    else
      "#{request.base_url}/og-image.png"
    end
  end

  def post_meta_author(post)
    post.user&.display_name
  end
end
