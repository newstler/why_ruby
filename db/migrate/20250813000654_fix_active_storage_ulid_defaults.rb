class FixActiveStorageUlidDefaults < ActiveRecord::Migration[8.0]
  def change
    # This migration is now empty as we handle ULID generation via the initializer
    # The initializer in config/initializers/active_storage_ulid.rb handles ULID generation
  end
end
