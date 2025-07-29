class Avo::Resources::User < Avo::BaseResource
  self.title = :username
  self.includes = [:contents, :comments]
  self.search = {
    query: -> { query.ransack(username_cont: params[:q], email_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :text, readonly: true
    field :avatar_url, as: :external_image
    field :username, as: :text, readonly: true
    field :email, as: :text, readonly: true
    field :github_id, as: :number, readonly: true
    field :role, as: :select, enum: ::User.roles
    field :archived, as: :boolean
    field :published_contents_count, as: :number, readonly: true
    field :published_comments_count, as: :number, readonly: true
    field :trusted?, as: :boolean, readonly: true
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :contents, as: :has_many
    field :comments, as: :has_many
    field :reports, as: :has_many
  end
  
  def actions
    action Avo::Actions::ToggleArchived
    action Avo::Actions::MakeAdmin
  end
end
