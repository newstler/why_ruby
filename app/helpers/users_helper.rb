module UsersHelper
  def user_meta_title(user)
    user.display_name
  end

  def user_meta_description(user)
    if user.bio.present?
      t("meta.users.show.summary_with_bio", bio: user.bio)
    else
      t("meta.users.show.summary_without_bio", display_name: user.display_name)
    end
  end

  def user_meta_keywords(user)
    t("meta.users.show.keywords", username: user.display_name)
  end

  def user_meta_image_url(user)
    if user.avatar_url.present?
      user.avatar_url
    else
      "#{request.base_url}/og-image.png"
    end
  end
end
