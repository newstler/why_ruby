module CategoriesHelper
  def category_meta_title(category)
    category.name
  end

  def category_meta_description(category)
    t("meta.categories.show.summary", category_name_lower: category.name.downcase)
  end

  def category_meta_keywords(category)
    t("meta.categories.show.keywords", category_name: category.name)
  end

  def category_meta_image_url(category)
    versioned_og_image_url
  end
end
