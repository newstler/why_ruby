class AddTimezoneToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :timezone, :string
  end
end
