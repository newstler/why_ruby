class UserResource < Madmin::Resource
  def self.actions
    [ :index, :show, :edit, :update ]
  end

  attribute :id, form: false, index: false
  attribute :username
  attribute :name
  attribute :email
  attribute :role
  attribute :location
  attribute :published_posts_count, form: false
  attribute :published_comments_count, form: false
  attribute :github_stars_sum, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.sortable_columns
    super + %w[published_posts_count published_comments_count github_stars_sum]
  end

  def self.searchable_attributes
    [ :username, :name, :email ]
  end

  def self.display_name(record)
    record.display_name
  end
end
