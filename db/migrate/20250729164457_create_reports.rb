class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }

      t.references :user, type: :string, null: false, foreign_key: true
      t.references :post, type: :string, null: false, foreign_key: true

      t.integer :reason, null: false # enum: spam:0, inappropriate:1, off_topic:2, harassment:3, misinformation:4, other:5
      t.text :description

      t.timestamps
    end

    add_index :reports, [ :user_id, :post_id ], unique: true
  end
end
