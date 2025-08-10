class Avo::TagsController < Avo::ResourcesController
  # Override to handle slug changes properly
  def update
    super
  rescue ActiveRecord::RecordNotFound
    # If the record wasn't found, redirect to index
    redirect_to avo.resources_tags_path, alert: "Tag not found"
  end
  
  private
  
  # Override the redirect path after update to use the new slug
  def after_update_path
    return params[:referrer] if params[:referrer].present?
    
    # Use the updated record's current slug/id for the redirect
    avo.resources_tag_path(record: @record, resource: @resource)
  end
end 