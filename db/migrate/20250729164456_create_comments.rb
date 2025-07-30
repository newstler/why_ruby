class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
      
      t.references :post, type: :string, null: false, foreign_key: true
      t.references :user, type: :string, null: false, foreign_key: true
      
      t.text :body, null: false
      t.boolean :published, default: false, null: false
      t.boolean :archived, default: false, null: false
      
      t.timestamps
    end
    
    add_index :comments, :published
    add_index :comments, :archived
    add_index :comments, :created_at
  end
end
