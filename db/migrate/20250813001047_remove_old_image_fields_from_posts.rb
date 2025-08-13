class RemoveOldImageFieldsFromPosts < ActiveRecord::Migration[8.0]
  def change
    # Remove the old image storage columns that are no longer needed
    remove_column :posts, :logo_png_base64, :text
    remove_column :posts, :title_image_url, :string

    # Also remove the temporary migration tracking column
    remove_column :posts, :images_migrated, :boolean
  end
end
