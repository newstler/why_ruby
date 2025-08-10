class Avo::Resources::Category < Avo::BaseResource
  self.title = :name
  self.includes = []
  self.model_class = ::Category
  self.default_view_type = :table
  self.index_query = -> { query.unscoped }
  self.record_selector = -> { record.slug.presence || record.id }
  

  
  self.search = {
    query: -> { ::Category.unscoped.ransack(name_cont: params[:q]).result(distinct: false) }
  }
  
  # Override to find records without default scope and use FriendlyId with history support
  def self.find_record(id, **kwargs)
    # First try to find by current slug or ID
    ::Category.unscoped.friendly.find(id)
  rescue ActiveRecord::RecordNotFound
    # If not found, try to find by historical slug
    slug_record = FriendlyId::Slug.where(sluggable_type: 'Category', slug: id).first
    if slug_record
      ::Category.unscoped.find(slug_record.sluggable_id)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def fields
    field :id, as: :text, readonly: true
    field :name, as: :text, required: true
    field :position, as: :number, required: true
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :posts, as: :has_many
  end
  
  def actions
    action Avo::Actions::BulkDelete
  end
end 