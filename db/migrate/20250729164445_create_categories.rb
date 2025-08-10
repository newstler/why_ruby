class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }

      t.string :name, null: false
      t.integer :position, null: false
      t.boolean :archived, default: false, null: false

      t.timestamps
    end

    add_index :categories, :name, unique: true
    add_index :categories, :position, unique: true
    add_index :categories, :archived
  end
end
