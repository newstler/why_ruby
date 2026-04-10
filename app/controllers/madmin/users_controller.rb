module Madmin
  class UsersController < Madmin::ResourceController
    def index
      super
      companies = @records.map(&:company).compact.reject(&:blank?).uniq
      @company_teams = Team.where(name: companies).index_by(&:name)
    end

    private

    def set_record
      @record = resource.model
        .includes(:posts, :comments, :testimonial, :projects)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run

      if params[:created_at_from].present? && params[:created_at_to].present?
        resources = resources.where(created_at: params[:created_at_from]..params[:created_at_to])
      elsif params[:created_at].present?
        date = Date.parse(params[:created_at])
        resources = resources.where("DATE(created_at) = ?", date)
      end

      if params[:role].present?
        resources = resources.where(role: params[:role])
      end

      if params[:trusted] == "true"
        resources = resources.trusted
      end

      dir = sort_direction == "asc" ? "ASC" : "DESC"

      case sort_column
      when "published_posts_count", "published_comments_count", "github_stars_sum"
        resources.reorder(Arel.sql("#{sort_column} #{dir}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
