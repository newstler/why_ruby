module Madmin
  class TestimonialsController < Madmin::ResourceController
    private

    def scoped_resources
      resources = super.includes(:user)

      if params[:published].present?
        resources = resources.where(published: params[:published] == "true")
      end

      resources
    end
  end
end
