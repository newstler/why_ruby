class CreateContents < ActiveRecord::Migration[8.1]
  def change
    create_table :contents, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
      
      t.references :user, type: :string, null: false, foreign_key: true
      t.references :category, type: :string, null: false, foreign_key: true
      
      t.string :title, null: false
      t.text :content # Required if url is blank
      t.string :url # Required if content is blank
      t.text :summary # AI-generated
      t.string :title_image_url
      
      t.integer :pin_position # Unique when not nil
      t.boolean :published, default: false, null: false
      t.boolean :archived, default: false, null: false
      
      # Moderation fields
      t.integer :reports_count, default: 0, null: false
      t.boolean :needs_admin_review, default: false, null: false
      
      t.timestamps
    end
    
    add_index :contents, :pin_position, unique: true, where: "pin_position IS NOT NULL"
    add_index :contents, :published
    add_index :contents, :archived
    add_index :contents, :needs_admin_review
    add_index :contents, :created_at
  end
end
