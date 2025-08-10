class Avo::Resources::User < Avo::BaseResource
  self.title = :username
  self.includes = [:posts, :comments]
  self.index_query = -> { query.unscoped }
  self.description = "Manage system users"
  self.record_selector = -> { record.slug.presence || record.id }
  
  self.search = {
    query: -> { User.unscoped.ransack(username_cont: params[:q], email_cont: params[:q], m: "or").result(distinct: false) }
  }
  
  # Override to find records without default scope and use FriendlyId with history support
  def self.find_record(id, **kwargs)
    # First try to find by current slug or ID
    ::User.unscoped.friendly.find(id)
  rescue ActiveRecord::RecordNotFound
    # If not found, try to find by historical slug
    slug_record = FriendlyId::Slug.where(sluggable_type: 'User', slug: id).first
    if slug_record
      ::User.unscoped.find(slug_record.sluggable_id)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def fields
    # Compact display for index
    field :id, as: :text, readonly: true, hide_on: [:index]
    field :avatar_url, as: :external_image, link_to_record: true, circular: true, size: :sm
    field :username, as: :text, readonly: true, link_to_record: true
    field :email, as: :text, readonly: true, hide_on: [:index]
    field :role, as: :select, enum: ::User.roles
    
    # Activity indicators for index
    field :published_posts_count, as: :number, readonly: true, name: "Posts"
    field :published_comments_count, as: :number, readonly: true, name: "Comments", hide_on: [:forms, :show]
    
    # Status
    field :trusted?, as: :boolean, readonly: true, name: "Trusted"
    
    # GitHub info - hide from index
    field :github_id, as: :number, readonly: true, hide_on: [:index]
    
    # Timestamps - only show created_at on index
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true, hide_on: [:index]
    
    # Associations - hide from index
    field :posts, as: :has_many, hide_on: [:index]
    field :comments, as: :has_many, hide_on: [:index]
    field :reports, as: :has_many, hide_on: [:index]
  end
  
  def actions
    action Avo::Actions::MakeAdmin
    action Avo::Actions::BulkDelete
  end
end
