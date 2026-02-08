class Avo::Resources::StarSnapshot < Avo::BaseResource
  self.title = :recorded_on
  self.includes = [ :project ]
  self.model_class = ::StarSnapshot
  self.description = "Daily star count snapshots for projects"
  self.default_view_type = :table

  def fields
    field :id, as: :text, readonly: true, hide_on: [ :index ]
    field :project, as: :belongs_to
    field :stars, as: :number
    field :recorded_on, as: :date
    field :created_at, as: :date_time, readonly: true, hide_on: [ :index ]
  end
end
