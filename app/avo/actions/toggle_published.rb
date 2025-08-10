class Avo::Actions::TogglePublished < Avo::BaseAction
  self.name = "Toggle Published"
  self.visible = -> { true }

  def handle(query:, fields:, current_user:, resource:, **args)
    # Ensure query is always a collection
    records = query.is_a?(ActiveRecord::Relation) ? query : [query]
    
    records.each do |record|
      record.update!(published: !record.published)
    end

    count = records.is_a?(Array) ? records.size : records.count
    succeed "Successfully toggled published status for #{count} #{'record'.pluralize(count)}."
  end
end 