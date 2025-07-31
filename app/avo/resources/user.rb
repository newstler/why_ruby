class Avo::Resources::User < Avo::BaseResource
  self.title = :username
  self.includes = [:posts, :comments]
  self.index_query = -> { query.unscoped }
  
  self.search = {
    query: -> { User.unscoped.ransack(username_cont: params[:q], email_cont: params[:q], m: "or").result(distinct: false) }
  }
  
  # Override to find records without default scope
  def self.find_record(id, **kwargs)
    ::User.unscoped.find(id)
  end

  def fields
    field :id, as: :text, readonly: true
    field :avatar_url, as: :external_image
    field :username, as: :text, readonly: true
    field :email, as: :text, readonly: true
    field :github_id, as: :number, readonly: true
    field :role, as: :select, enum: ::User.roles
    field :archived, as: :boolean
    field :published_posts_count, as: :number, readonly: true
    field :published_comments_count, as: :number, readonly: true
    field :trusted?, as: :boolean, readonly: true
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :posts, as: :has_many
    field :comments, as: :has_many
    field :reports, as: :has_many
  end
  
  def actions
    action Avo::Actions::ToggleArchived
    action Avo::Actions::MakeAdmin
  end
end
