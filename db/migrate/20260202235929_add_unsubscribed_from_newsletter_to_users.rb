class AddUnsubscribedFromNewsletterToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :unsubscribed_from_newsletter, :boolean, default: false, null: false
  end
end
