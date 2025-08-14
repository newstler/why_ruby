class AddIsSuccessStoryToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :is_success_story, :boolean, default: false, null: false
    add_index :categories, :is_success_story, unique: true, where: "is_success_story = true"
  end
end
