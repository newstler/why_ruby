module TagsHelper
  def tag_meta_title(tag)
    tag.name
  end

  def tag_meta_description(tag)
    t("meta.tags.show.summary", tag_name: tag.name)
  end

  def tag_meta_keywords(tag)
    t("meta.tags.show.keywords", tag_name: tag.name)
  end

  def tag_meta_image_url(tag)
    "#{request.base_url}/og-image.png"
  end
end
