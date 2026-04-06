class RemoveNotNullFromArticlesTitle < ActiveRecord::Migration[8.2]
  def change
    change_column_null :articles, :title, true
  end
end
