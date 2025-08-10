class Avo::Actions::BulkDelete < Avo::BaseAction
  self.name = "Bulk Delete"
  self.visible = -> { true }
  self.message = -> do
    count = query.is_a?(ActiveRecord::Relation) ? query.count : 1
    "Are you sure you want to delete #{pluralize(count, 'record')}? This action cannot be undone."
  end
  self.confirm_button_label = "Delete"
  self.cancel_button_label = "Cancel"

  def handle(query:, fields:, current_user:, resource:, **args)
    # Ensure query is always a collection
    records = query.is_a?(ActiveRecord::Relation) ? query : [query]
    count = records.is_a?(Array) ? records.size : records.count
    
    # Get the model name from the first record if available
    model_name = if records.any?
      records.first.class.name.underscore.humanize.downcase
    else
      "record"
    end
    
    begin
      # Delete each record individually to respect callbacks and associations
      records.each(&:destroy!)
      
      succeed "Successfully deleted #{count} #{model_name.pluralize(count)}."
    rescue => e
      error "Failed to delete records: #{e.message}"
    end
  end
end
