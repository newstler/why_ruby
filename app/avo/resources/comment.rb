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
    field :id, as: :text, readonly: true, hide_on: [:index]
    
    # Show truncated body on index
    field :body, as: :text, 
      required: true,
      only_on: [:index],
      format_using: -> { value.to_s.truncate(100) if value },
      link_to_record: true
      
    # Full body for other views
    field :body, as: :textarea, required: true, hide_on: [:index]
    
    # Associations - show on index for context
    field :user, as: :belongs_to
    field :post, as: :belongs_to, 
      format_using: -> { record.post&.title&.truncate(50) if view == :index }
    
    # Status
    field :published, as: :boolean
    
    # Timestamps
    field :created_at, as: :date_time, readonly: true, hide_on: [:index]
    field :updated_at, as: :date_time, readonly: true, only_on: [:index]
  end
  
  def actions
    action Avo::Actions::TogglePublished
    action Avo::Actions::BulkDelete
  end
end 