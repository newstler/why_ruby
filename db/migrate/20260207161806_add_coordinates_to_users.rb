class AddCoordinatesToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :latitude, :float
    add_column :users, :longitude, :float
    add_index :users, [ :latitude, :longitude ], name: "index_users_on_coordinates"
  end
end
