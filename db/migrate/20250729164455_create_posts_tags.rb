class CreatePostsTags < ActiveRecord::Migration[8.1]
  def change
    create_table :posts_tags, id: false, force: true do |t|
      t.references :post, type: :string, null: false, foreign_key: true
      t.references :tag, type: :string, null: false, foreign_key: true
    end
    
    add_index :posts_tags, [:post_id, :tag_id], unique: true
    add_index :posts_tags, [:tag_id, :post_id]
  end
end
