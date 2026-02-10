class RemoveGithubReposFromUsers < ActiveRecord::Migration[8.2]
  def change
    remove_column :users, :github_repos, :text
  end
end
