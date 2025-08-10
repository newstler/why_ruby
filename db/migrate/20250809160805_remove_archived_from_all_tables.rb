class RemoveArchivedFromAllTables < ActiveRecord::Migration[8.0]
  def change
    # Remove archived column and index from users
    remove_index :users, :archived if index_exists?(:users, :archived)
    remove_column :users, :archived, :boolean

    # Remove archived column and index from posts
    remove_index :posts, :archived if index_exists?(:posts, :archived)
    remove_column :posts, :archived, :boolean

    # Remove archived column and index from comments
    remove_index :comments, :archived if index_exists?(:comments, :archived)
    remove_column :comments, :archived, :boolean

    # Remove archived column and index from categories
    remove_index :categories, :archived if index_exists?(:categories, :archived)
    remove_column :categories, :archived, :boolean

    # Remove archived column and index from tags
    remove_index :tags, :archived if index_exists?(:tags, :archived)
    remove_column :tags, :archived, :boolean
  end
end
