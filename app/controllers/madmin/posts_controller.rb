module Madmin
  class PostsController < Madmin::ResourceController
    private

    def scoped_resources
      resources = super.includes(:user, :category).unscope(:order)

      if params[:post_type].present?
        resources = resources.where(post_type: params[:post_type])
      end

      if params[:published].present?
        resources = resources.where(published: params[:published] == "true")
      end

      if params[:needs_review] == "true"
        resources = resources.where(needs_admin_review: true)
      end

      resources
    end
  end
end
