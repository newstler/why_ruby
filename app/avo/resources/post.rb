class Avo::Resources::Post < Avo::BaseResource
  self.title = :title
  self.includes = [:user, :category, :tags]
  self.model_class = ::Post
  self.index_query = -> { query.unscoped }
  
  self.search = {
    query: -> { Post.unscoped.ransack(title_cont: params[:q], content_cont: params[:q], m: "or").result(distinct: false) }
  }
  
  # Override to find records without default scope
  def self.find_record(id, **kwargs)
    ::Post.unscoped.find(id)
  end

  def fields
    field :id, as: :text, readonly: true
    field :title, as: :text, required: true
    field :content, as: :trix
    field :url, as: :text, format_using: -> { link_to(value, value, target: "_blank") if value.present? }
    field :summary, as: :trix, readonly: true
    field :title_image_url, as: :text
    field :pin_position, as: :number
    field :published, as: :boolean
    field :reports_count, as: :number, readonly: true
    field :needs_admin_review, as: :boolean
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :user, as: :belongs_to
    field :category, as: :belongs_to
    field :tags, as: :has_and_belongs_to_many
    field :comments, as: :has_many
    field :reports, as: :has_many
  end
  
  def actions
    action Avo::Actions::TogglePublished
    action Avo::Actions::RegenerateSummary
    # action Avo::Actions::PinContent
    # action Avo::Actions::ClearReports
  end
  
  # def filters
  #   filter Avo::Filters::Published
  #   filter Avo::Filters::NeedsReview
  #   filter Avo::Filters::ContentType
  # end
end 