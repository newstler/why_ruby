class TagResource < Madmin::Resource
  def self.actions
    [ :index, :show, :edit, :update ]
  end

  attribute :id, form: false, index: false
  attribute :name
  attribute :slug, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.searchable_attributes
    [ :name ]
  end

  def self.display_name(record)
    record.name
  end
end
