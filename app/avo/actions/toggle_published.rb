class Avo::Actions::TogglePublished < Avo::BaseAction
  self.name = "Toggle Published"
  self.visible = -> { true }

  def handle(query:, fields:, current_user:, resource:, **args)
    # Ensure query is always a collection
    records = case query
              when ActiveRecord::Relation
                query
              when Array
                query  # Already a collection from our patch
              else
                [query]  # Single record, wrap in array
              end
    
    records.each do |record|
      record.update!(published: !record.published)
    end

    count = records.is_a?(Array) ? records.size : records.count
    succeed "Successfully toggled published status for #{count} #{'record'.pluralize(count)}."
  end
end 