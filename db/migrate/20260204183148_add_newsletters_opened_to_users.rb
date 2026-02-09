class AddNewslettersOpenedToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :newsletters_opened, :json, default: []
  end
end
