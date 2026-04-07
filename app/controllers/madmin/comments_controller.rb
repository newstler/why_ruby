module Madmin
  class CommentsController < Madmin::ResourceController
    private

    def scoped_resources
      resources = super.includes(:user, :post)

      if params[:published].present?
        resources = resources.where(published: params[:published] == "true")
      end

      resources
    end
  end
end
