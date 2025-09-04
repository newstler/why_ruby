class AddGithubStatsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :github_stars_sum, :integer
    add_column :users, :github_repos_count, :integer
  end
end
