class AddPurposeToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :purpose, :string, default: "conversation"
    add_index :chats, :purpose
  end
end
