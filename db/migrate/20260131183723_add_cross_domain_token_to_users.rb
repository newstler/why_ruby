class AddCrossDomainTokenToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :cross_domain_token, :string
    add_column :users, :cross_domain_token_expires_at, :datetime
    add_index :users, :cross_domain_token, unique: true
  end
end
