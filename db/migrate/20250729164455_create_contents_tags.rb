class CreateContentsTags < ActiveRecord::Migration[8.1]
  def change
    create_table :contents_tags, id: false, force: true do |t|
      t.references :content, type: :string, null: false, foreign_key: true
      t.references :tag, type: :string, null: false, foreign_key: true
    end
    
    add_index :contents_tags, [:content_id, :tag_id], unique: true
    add_index :contents_tags, [:tag_id, :content_id]
  end
end
