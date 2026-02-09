module UsersHelper
  def linkify_company(company)
    company.gsub(/@[\w-]+/) do |handle|
      name = handle.delete_prefix("@")
      link_to(handle, "https://github.com/#{name}", target: "_blank", rel: "noopener",
        class: "text-gray-500 underline decoration-gray-300 hover:decoration-red-500 hover:text-red-600 transition-colors",
        data: { turbo_frame: "_top" })
    end.html_safe
  end

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
      versioned_og_image_url("og-image-community.png")
    end
  end
end
