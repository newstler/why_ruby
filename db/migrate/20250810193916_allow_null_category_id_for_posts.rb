class AllowNullCategoryIdForPosts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :posts, :category_id, true
  end
end