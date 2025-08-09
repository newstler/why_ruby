class AddGithubProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    add_column :users, :bio, :text
    add_column :users, :company, :string
    add_column :users, :website, :string
    add_column :users, :twitter, :string
    add_column :users, :linkedin, :string
    add_column :users, :location, :string
    add_column :users, :github_repos, :text
    add_column :users, :github_data_updated_at, :datetime
  end
end
