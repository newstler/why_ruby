class Avo::Resources::Report < Avo::BaseResource
  self.title = :reason
  self.includes = [:user, :post]
  
  def fields
    field :id, as: :text, readonly: true
    field :reason, as: :select, enum: ::Report.reasons
    field :description, as: :textarea
    field :created_at, as: :date_time, readonly: true
    
    # Associations
    field :user, as: :belongs_to
    field :post, as: :belongs_to
  end
end 