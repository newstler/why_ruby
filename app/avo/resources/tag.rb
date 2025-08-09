class Avo::Resources::Tag < Avo::BaseResource
  self.title = :name
  self.includes = []
  self.index_query = -> { query.unscoped }
  
  self.search = {
    query: -> { Tag.unscoped.ransack(name_cont: params[:q]).result(distinct: false) }
  }
  
  # Override to find records without default scope
  def self.find_record(id, **kwargs)
    ::Tag.unscoped.find(id)
  end

  def fields
    field :id, as: :text, readonly: true
    field :name, as: :text, required: true
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :posts, as: :has_and_belongs_to_many
  end
  
  def actions
  end
end 