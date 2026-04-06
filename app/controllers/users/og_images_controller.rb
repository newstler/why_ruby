class Users::OgImagesController < ApplicationController
  def show
    @users = User.where(public: true)
                 .where.not(avatar_url: [ nil, "" ])
                 .order(Arel.sql("COALESCE(github_stars_sum, 0) + COALESCE(published_posts_count, 0) * 10 + COALESCE(published_comments_count, 0) DESC"))
    @total_users_count = User.visible.count
    render layout: false
  end
end
