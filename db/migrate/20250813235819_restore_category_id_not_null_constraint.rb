class RestoreCategoryIdNotNullConstraint < ActiveRecord::Migration[8.1]
  def up
    # First ensure all posts have a category_id
    # (they should already have one from the previous migration)
    success_category = Category.find_by(is_success_story: true)

    if success_category
      # Update any posts with nil category_id (shouldn't be any, but just in case)
      Post.where(category_id: nil).update_all(category_id: success_category.id)
    end

    # Now add the NOT NULL constraint
    change_column_null :posts, :category_id, false
  end

  def down
    # Allow NULL values again
    change_column_null :posts, :category_id, true
  end
end
