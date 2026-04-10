class ReportResource < Madmin::Resource
  def self.actions
    [ :index, :show ]
  end

  attribute :id, form: false, index: false
  attribute :reason
  attribute :description
  attribute :user
  attribute :post
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.searchable_attributes
    [ :description ]
  end

  def self.display_name(record)
    "#{record.reason.titleize} report on #{record.post.title.truncate(40)}"
  end
end
