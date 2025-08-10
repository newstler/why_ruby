class Avo::CategoriesController < Avo::ResourcesController
  # Override to handle slug changes properly
  def update
    super
  rescue ActiveRecord::RecordNotFound
    # If the record wasn't found, redirect to index
    redirect_to avo.resources_categories_path, alert: "Category not found"
  end
  
  private
  
  # Override the redirect path after update to use the new slug
  def after_update_path
    return params[:referrer] if params[:referrer].present?
    
    # Use the updated record's current slug for the redirect
    # @record should be the updated category at this point
    if @record
      avo.resources_category_path(id: @record.slug || @record.id)
    else
      avo.resources_categories_path
    end
  end
end 