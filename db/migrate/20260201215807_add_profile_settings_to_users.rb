class AddProfileSettingsToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :public, :boolean, default: true, null: false
    add_column :users, :open_to_work, :boolean, default: false, null: false
    add_column :users, :hidden_repos, :text
  end
end
