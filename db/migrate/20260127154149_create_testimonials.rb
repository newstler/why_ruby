class CreateTestimonials < ActiveRecord::Migration[8.2]
  def change
    create_table :testimonials, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
      t.string :user_id, null: false
      t.text :quote, null: false
      t.string :heading
      t.string :subheading
      t.text :body_text
      t.boolean :published, default: false
      t.text :ai_feedback
      t.integer :ai_attempts, default: 0
      t.integer :position

      t.timestamps
    end

    add_index :testimonials, :user_id, unique: true
    add_index :testimonials, :heading, unique: true
    add_index :testimonials, :published
    add_index :testimonials, :position
  end
end
