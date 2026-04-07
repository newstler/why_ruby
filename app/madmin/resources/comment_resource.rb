class CommentResource < Madmin::Resource
  def self.actions
    [ :index, :show, :edit, :update ]
  end

  attribute :id, form: false, index: false
  attribute :body
  attribute :published
  attribute :user
  attribute :post
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.searchable_attributes
    [ :body ]
  end

  def self.display_name(record)
    record.body.truncate(60)
  end
end
