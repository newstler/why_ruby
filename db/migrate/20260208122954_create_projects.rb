class CreateProjects < ActiveRecord::Migration[8.2]
  def change
    create_table :projects, id: :string, default: -> { "uuid7()" } do |t|
      t.string :user_id, null: false
      t.string :name, null: false
      t.text :description
      t.integer :stars, default: 0, null: false
      t.string :github_url, null: false
      t.integer :forks_count, default: 0, null: false
      t.integer :size, default: 0, null: false
      t.json :topics, default: []
      t.datetime :pushed_at
      t.boolean :hidden, default: false, null: false
      t.boolean :archived, default: false, null: false

      t.timestamps
    end

    add_index :projects, :user_id
    add_index :projects, [ :user_id, :github_url ], unique: true
    add_index :projects, :stars
    add_index :projects, :archived
    add_foreign_key :projects, :users
  end
end
