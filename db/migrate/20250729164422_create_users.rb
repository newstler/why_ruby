class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }

      # GitHub OAuth fields
      t.integer :github_id, null: false
      t.string :username, null: false
      t.string :email, null: false
      t.string :avatar_url

      # Role system
      t.integer :role, default: 0, null: false # enum: member:0, admin:1

      # Soft deletion
      t.boolean :archived, default: false, null: false

      # Counter caches
      t.integer :published_posts_count, default: 0, null: false
      t.integer :published_comments_count, default: 0, null: false

      t.timestamps
    end

    add_index :users, :github_id, unique: true
    add_index :users, :username, unique: true
    add_index :users, :email, unique: true
    add_index :users, :archived
  end
end
