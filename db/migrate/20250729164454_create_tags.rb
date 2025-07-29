class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
      
      t.string :name, null: false
      t.boolean :archived, default: false, null: false
      
      t.timestamps
    end
    
    add_index :tags, :name, unique: true
    add_index :tags, :archived
  end
end
