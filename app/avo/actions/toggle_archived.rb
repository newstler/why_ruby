class Avo::Actions::ToggleArchived < Avo::BaseAction
  self.name = "Toggle Archived"
  self.visible = -> { true }

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |record|
      record.update!(archived: !record.archived)
    end

    succeed "Successfully toggled archived status for #{query.count} #{'record'.pluralize(query.count)}."
  end
end 