class PostResource < Madmin::Resource
  def self.actions
    [ :index, :show, :edit, :update ]
  end

  attribute :id, form: false, index: false
  attribute :title
  attribute :post_type
  attribute :published
  attribute :needs_admin_review
  attribute :pin_position
  attribute :url
  attribute :summary, form: false
  attribute :user
  attribute :category
  attribute :comments_count, form: false
  attribute :reports_count, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.sortable_columns
    super + %w[comments_count reports_count]
  end

  def self.searchable_attributes
    [ :title, :url ]
  end

  def self.display_name(record)
    record.title.truncate(60)
  end
end
