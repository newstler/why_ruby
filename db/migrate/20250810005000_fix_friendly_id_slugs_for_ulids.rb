class FixFriendlyIdSlugsForUlids < ActiveRecord::Migration[8.1]
  def up
    # Remove the old friendly_id_slugs table
    drop_table :friendly_id_slugs if table_exists?(:friendly_id_slugs)
    
    # Recreate with string sluggable_id for ULID support
    create_table :friendly_id_slugs do |t|
      t.string :slug, null: false
      t.string :sluggable_id, null: false  # Changed from integer to string for ULIDs
      t.string :sluggable_type, limit: 50
      t.string :scope
      t.datetime :created_at
    end
    
    add_index :friendly_id_slugs, [:sluggable_type, :sluggable_id]
    add_index :friendly_id_slugs, [:slug, :sluggable_type], length: {slug: 140, sluggable_type: 50}
    add_index :friendly_id_slugs, [:slug, :sluggable_type, :scope], 
              length: {slug: 70, sluggable_type: 50, scope: 70}, unique: true
    
    # Regenerate slugs for all models to populate history correctly
    say_with_time "Regenerating slug history for all models" do
      [Post, Category, Tag, User].each do |model_class|
        model_class.find_each do |record|
          # Force slug regeneration to create history entries
          record.slug = nil
          record.save!(validate: false)
        end
      end
    end
  end
  
  def down
    drop_table :friendly_id_slugs
    
    # Recreate the original table structure
    create_table :friendly_id_slugs do |t|
      t.string :slug, null: false
      t.integer :sluggable_id, null: false
      t.string :sluggable_type, limit: 50
      t.string :scope
      t.datetime :created_at
    end
    
    add_index :friendly_id_slugs, [:sluggable_type, :sluggable_id]
    add_index :friendly_id_slugs, [:slug, :sluggable_type], length: {slug: 140, sluggable_type: 50}
    add_index :friendly_id_slugs, [:slug, :sluggable_type, :scope], 
              length: {slug: 70, sluggable_type: 50, scope: 70}, unique: true
  end
end
