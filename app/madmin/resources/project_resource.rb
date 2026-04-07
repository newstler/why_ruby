class ProjectResource < Madmin::Resource
  def self.actions
    [ :index, :show ]
  end

  attribute :id, form: false, index: false
  attribute :name
  attribute :github_url
  attribute :description
  attribute :stars
  attribute :forks_count
  attribute :hidden
  attribute :archived
  attribute :user
  attribute :pushed_at
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.sortable_columns
    super + %w[stars forks_count]
  end

  def self.searchable_attributes
    [ :name, :github_url ]
  end

  def self.display_name(record)
    record.name
  end
end
