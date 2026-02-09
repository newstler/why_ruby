class AddNewslettersReceivedToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :newsletters_received, :json, default: []
  end
end
