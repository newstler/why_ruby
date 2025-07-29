class Avo::Resources::Comment < Avo::BaseResource
  self.title = :body
  self.includes = [:user, :content]
  self.search = {
    query: -> { query.ransack(body_cont: params[:q]).result(distinct: false) }
  }

  def fields
    field :id, as: :text, readonly: true
    field :body, as: :textarea, required: true
    field :published, as: :boolean
    field :archived, as: :boolean
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :user, as: :belongs_to
    field :content, as: :belongs_to
  end
  
  def actions
    action Avo::Actions::TogglePublished
    action Avo::Actions::ToggleArchived
  end
end 