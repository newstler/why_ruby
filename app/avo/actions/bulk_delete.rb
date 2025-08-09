class Avo::Actions::BulkDelete < Avo::BaseAction
  self.name = "Bulk Delete"
  self.visible = -> { true }
  self.message = -> do
    "Are you sure you want to delete #{pluralize(query.count, 'record')}? This action cannot be undone."
  end
  self.confirm_button_label = "Delete"
  self.cancel_button_label = "Cancel"

  def handle(query:, fields:, current_user:, resource:, **args)
    count = query.count
    
    # Get the model name from the first record if available
    model_name = if query.any?
      query.first.class.name.underscore.humanize.downcase
    else
      "record"
    end
    
    begin
      # Delete each record individually to respect callbacks and associations
      query.each(&:destroy!)
      
      succeed "Successfully deleted #{count} #{model_name.pluralize(count)}."
    rescue => e
      error "Failed to delete records: #{e.message}"
    end
  end
end
