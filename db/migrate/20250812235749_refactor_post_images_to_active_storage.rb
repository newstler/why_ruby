class RefactorPostImagesToActiveStorage < ActiveRecord::Migration[8.0]
  def up
    # First, run the active storage tables migration if needed
    # The data migration will be handled in a rake task after deployment

    # We'll keep the old columns temporarily for data migration
    # They will be removed in a follow-up migration after data is migrated
    add_column :posts, :images_migrated, :boolean, default: false, null: false
  end

  def down
    remove_column :posts, :images_migrated
  end
end
