module Madmin
  class CategoriesController < Madmin::ResourceController
    private

    def scoped_resources
      super.includes(:posts)
    end
  end
end
