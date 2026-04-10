module Madmin
  class ReportsController < Madmin::ResourceController
    private

    def scoped_resources
      resources = super.includes(:user, :post)

      if params[:reason].present?
        resources = resources.where(reason: params[:reason])
      end

      resources
    end
  end
end
