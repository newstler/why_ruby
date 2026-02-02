class AddBioHtmlToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :bio_html, :text

    # Populate bio_html for existing users
    reversible do |dir|
      dir.up do
        # We'll populate this via a rake task after migration
        # since we need the helper method which isn't available in migrations
      end
    end
  end
end
