class AddCartoApiKeyToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :carto_api_key, :string
  end
end
