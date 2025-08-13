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
      post_image_url(post)
    else
      "#{request.base_url}/og-image.png"
    end
  end

  def post_meta_author(post)
    post.user&.display_name
  end
end
