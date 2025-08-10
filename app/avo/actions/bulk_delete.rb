class Avo::Actions::BulkDelete < Avo::BaseAction
  self.name = "Bulk Delete"
  self.visible = -> { true }
  self.message = -> do
    count = case query
    when ActiveRecord::Relation
              query.count
    when Array
              query.size
    else
              # Single record
              1
    end
    "Are you sure you want to delete #{pluralize(count, 'record')}? This action cannot be undone."
  end
  self.confirm_button_label = "Delete"
  self.cancel_button_label = "Cancel"

  def handle(query:, fields:, current_user:, resource:, **args)
    # Ensure query is always a collection
    records = case query
    when ActiveRecord::Relation
                query
    when Array
                query  # Already a collection from our patch
    else
                [ query ]  # Single record, wrap in array
    end
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
