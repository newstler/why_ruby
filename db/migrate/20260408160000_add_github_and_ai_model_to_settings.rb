class AddGithubAndAiModelToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :default_ai_model, :string
    add_column :settings, :github_whyruby_client_id, :string
    add_column :settings, :github_whyruby_client_secret, :string
    add_column :settings, :github_rubycommunity_client_id, :string
    add_column :settings, :github_rubycommunity_client_secret, :string
    add_column :settings, :github_api_token, :string
  end
end
