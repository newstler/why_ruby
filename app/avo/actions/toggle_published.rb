class Avo::Actions::TogglePublished < Avo::BaseAction
  self.name = "Toggle Published"
  self.visible = -> { true }

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |record|
      record.update!(published: !record.published)
    end

    succeed "Successfully toggled published status for #{query.count} #{'record'.pluralize(query.count)}."
  end
end 