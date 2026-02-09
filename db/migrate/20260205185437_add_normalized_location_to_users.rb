class AddNormalizedLocationToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :normalized_location, :string
    add_index :users, :normalized_location
  end
end
