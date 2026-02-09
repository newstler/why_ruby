class CreateStarSnapshotsAndAddStarsGainedToUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :star_snapshots, id: :string, default: -> { "uuid7()" } do |t|
      t.string :project_id, null: false
      t.integer :stars, null: false, default: 0
      t.date :recorded_on, null: false

      t.timestamps
    end

    add_index :star_snapshots, [ :project_id, :recorded_on ], unique: true
    add_index :star_snapshots, :recorded_on
    add_foreign_key :star_snapshots, :projects

    add_column :users, :stars_gained, :integer, default: 0, null: false
  end
end
