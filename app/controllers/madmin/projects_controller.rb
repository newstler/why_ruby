module Madmin
  class ProjectsController < Madmin::ResourceController
    private

    def scoped_resources
      resources = super.includes(:user)

      if params[:hidden] == "true"
        resources = resources.where(hidden: true)
      end

      if params[:archived] == "true"
        resources = resources.where(archived: true)
      end

      resources
    end
  end
end
