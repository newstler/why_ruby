class AddImageProcessingFieldsToPosts < ActiveRecord::Migration[8.0]
  def up
    # Add new columns for image processing
    add_column :posts, :image_blur_data, :text
    add_column :posts, :image_variants, :json

    # NOTE: Image processing moved to rake task
    # Run after deployment: rails images:process_initial
  end

  def down
    remove_column :posts, :image_blur_data
    remove_column :posts, :image_variants

    # Note: We don't restore original images on rollback
    # The featured_image attachment remains intact
  end
end
