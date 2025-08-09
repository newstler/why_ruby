class Avo::Resources::Comment < Avo::BaseResource
  self.title = :body
  self.includes = [:user, :post]
  self.index_query = -> { query.unscoped }
  
  self.search = {
    query: -> { Comment.unscoped.ransack(body_cont: params[:q]).result(distinct: false) }
  }
  
  # Override to find records without default scope
  def self.find_record(id, **kwargs)
    ::Comment.unscoped.find(id)
  end

  def fields
    field :id, as: :text, readonly: true
    field :body, as: :textarea, required: true
    field :published, as: :boolean
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :user, as: :belongs_to
    field :post, as: :belongs_to
  end
  
  def actions
    action Avo::Actions::TogglePublished
  end
end 