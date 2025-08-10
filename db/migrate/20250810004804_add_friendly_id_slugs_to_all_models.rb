class AddFriendlyIdSlugsToAllModels < ActiveRecord::Migration[8.1]
  def up
    # Add slug columns to all models
    add_column :posts, :slug, :string
    add_index :posts, :slug
    
    add_column :categories, :slug, :string
    add_index :categories, :slug
    
    add_column :tags, :slug, :string
    add_index :tags, :slug
    
    add_column :users, :slug, :string
    add_index :users, :slug
    
    # Generate slugs for existing records
    say_with_time "Generating slugs for Posts" do
      Post.reset_column_information
      Post.find_each do |post|
        post.slug = nil
        post.save!(validate: false)
      end
    end
    
    say_with_time "Generating slugs for Categories" do
      Category.reset_column_information
      Category.find_each do |category|
        category.slug = nil
        category.save!(validate: false)
      end
    end
    
    say_with_time "Generating slugs for Tags" do
      Tag.reset_column_information
      Tag.find_each do |tag|
        tag.slug = nil
        tag.save!(validate: false)
      end
    end
    
    say_with_time "Generating slugs for Users" do
      User.reset_column_information
      User.find_each do |user|
        user.slug = nil
        user.save!(validate: false)
      end
    end
  end
  
  def down
    remove_index :users, :slug
    remove_column :users, :slug
    
    remove_index :tags, :slug
    remove_column :tags, :slug
    
    remove_index :categories, :slug
    remove_column :categories, :slug
    
    remove_index :posts, :slug
    remove_column :posts, :slug
  end
end