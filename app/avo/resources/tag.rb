class Avo::Resources::Tag < Avo::BaseResource
  self.title = :name
  self.includes = []
  self.search = {
    query: -> { query.ransack(name_cont: params[:q]).result(distinct: false) }
  }

  def fields
    field :id, as: :text, readonly: true
    field :name, as: :text, required: true
    field :archived, as: :boolean
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :posts, as: :has_and_belongs_to_many
  end
  
  def actions
    action Avo::Actions::ToggleArchived
  end
end 