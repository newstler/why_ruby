# frozen_string_literal: true

namespace :db do
  desc "Transform ULID primary keys to UUIDv7 format"
  task transform_ulid_to_uuid7: :environment do
    require "securerandom"

    puts "Starting ULID to UUIDv7 transformation..."
    puts "=" * 60

    # Tables with their foreign key relationships
    # Format: { table_name: { pk: 'id', fks: { column: :referenced_table } } }
    tables_config = {
      users: { pk: "id", fks: {} },
      categories: { pk: "id", fks: {} },
      tags: { pk: "id", fks: {} },
      admins: { pk: "id", fks: {} },
      active_storage_blobs: { pk: "id", fks: {} },
      posts: { pk: "id", fks: { user_id: :users, category_id: :categories } },
      comments: { pk: "id", fks: { user_id: :users, post_id: :posts } },
      reports: { pk: "id", fks: { user_id: :users, post_id: :posts } },
      testimonials: { pk: "id", fks: { user_id: :users } },
      active_storage_attachments: { pk: "id", fks: { blob_id: :active_storage_blobs } },
      active_storage_variant_records: { pk: "id", fks: { blob_id: :active_storage_blobs } },
      posts_tags: { pk: nil, fks: { post_id: :posts, tag_id: :tags } },
      friendly_id_slugs: { pk: "id", fks: {} } # integer PK, but has sluggable_id reference
    }

    # Step 1: Generate all new IDs and build mapping
    puts "\nPhase 1: Generating ID mappings..."
    id_mappings = {} # { table_name: { old_id => new_uuid7 } }

    tables_config.each do |table, config|
      next if config[:pk].nil? # Skip join tables
      next if table == :friendly_id_slugs # Integer PK

      id_mappings[table] = {}

      ActiveRecord::Base.connection.execute("SELECT id FROM #{table}").each do |row|
        old_id = row["id"]
        new_id = generate_uuid7
        id_mappings[table][old_id] = new_id
      end

      puts "  #{table}: #{id_mappings[table].size} IDs mapped"
    end

    # Step 2: Disable foreign key constraints
    puts "\nPhase 2: Disabling foreign key constraints..."
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")

    begin
      ActiveRecord::Base.transaction do
        # Step 3: Update primary keys in tables without FK dependencies first
        puts "\nPhase 3: Updating primary keys (independent tables)..."
        %i[users categories tags admins active_storage_blobs].each do |table|
          update_primary_keys(table, id_mappings[table])
        end

        # Step 4: Update tables with FK dependencies
        puts "\nPhase 4: Updating tables with foreign key dependencies..."

        # Posts depend on users and categories
        update_primary_keys_and_fks(:posts, id_mappings[:posts], {
          user_id: id_mappings[:users],
          category_id: id_mappings[:categories]
        })

        # Comments depend on users and posts
        update_primary_keys_and_fks(:comments, id_mappings[:comments], {
          user_id: id_mappings[:users],
          post_id: id_mappings[:posts]
        })

        # Reports depend on users and posts
        update_primary_keys_and_fks(:reports, id_mappings[:reports], {
          user_id: id_mappings[:users],
          post_id: id_mappings[:posts]
        })

        # Testimonials depend on users
        update_primary_keys_and_fks(:testimonials, id_mappings[:testimonials], {
          user_id: id_mappings[:users]
        })

        # ActiveStorage attachments depend on blobs and polymorphic record
        update_active_storage_attachments(id_mappings)

        # ActiveStorage variant records depend on blobs
        update_primary_keys_and_fks(:active_storage_variant_records, id_mappings[:active_storage_variant_records], {
          blob_id: id_mappings[:active_storage_blobs]
        })

        # Step 5: Update join table (posts_tags)
        puts "\nPhase 5: Updating join table (posts_tags)..."
        update_join_table(:posts_tags, {
          post_id: id_mappings[:posts],
          tag_id: id_mappings[:tags]
        })

        # Step 6: Update friendly_id_slugs
        puts "\nPhase 6: Updating friendly_id_slugs..."
        update_friendly_id_slugs(id_mappings)

        # Step 7: Update JSON fields (posts.image_variants)
        puts "\nPhase 7: Updating JSON fields (posts.image_variants)..."
        update_image_variants(id_mappings[:active_storage_blobs])
      end

      puts "\nTransformation completed successfully!"
    ensure
      # Step 8: Re-enable foreign key constraints
      puts "\nPhase 8: Re-enabling foreign key constraints..."
      ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
    end

    puts "\n" + "=" * 60
    puts "ID transformation complete!"
  end

  private

  def generate_uuid7
    # UUIDv7: timestamp-based UUID with random suffix
    # Format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
    timestamp_ms = (Time.now.to_f * 1000).to_i
    timestamp_hex = format("%012x", timestamp_ms)

    random_a = SecureRandom.hex(2)
    random_b = SecureRandom.hex(8)

    # Set version (7) and variant (8, 9, a, or b)
    version_and_random = "7" + random_a[1..3]
    variant_and_random = format("%x", (random_b[0].to_i(16) & 0x3) | 0x8) + random_b[1..15]

    "#{timestamp_hex[0..7]}-#{timestamp_hex[8..11]}-#{version_and_random}-#{variant_and_random[0..3]}-#{variant_and_random[4..15]}"
  end

  def update_primary_keys(table, mappings)
    return if mappings.empty?

    puts "  Updating #{table}..."
    mappings.each do |old_id, new_id|
      ActiveRecord::Base.connection.execute(
        "UPDATE #{table} SET id = #{ActiveRecord::Base.connection.quote(new_id)} WHERE id = #{ActiveRecord::Base.connection.quote(old_id)}"
      )
    end
    puts "    Updated #{mappings.size} records"
  end

  def update_primary_keys_and_fks(table, pk_mappings, fk_mappings)
    return if pk_mappings.empty?

    puts "  Updating #{table}..."

    pk_mappings.each do |old_pk, new_pk|
      # Build SET clause with all FK updates
      set_parts = [ "id = #{ActiveRecord::Base.connection.quote(new_pk)}" ]

      fk_mappings.each do |fk_column, fk_map|
        # Get current FK value and map it
        result = ActiveRecord::Base.connection.execute(
          "SELECT #{fk_column} FROM #{table} WHERE id = #{ActiveRecord::Base.connection.quote(old_pk)}"
        ).first

        if result && result[fk_column.to_s]
          old_fk = result[fk_column.to_s]
          new_fk = fk_map[old_fk]
          set_parts << "#{fk_column} = #{ActiveRecord::Base.connection.quote(new_fk)}" if new_fk
        end
      end

      ActiveRecord::Base.connection.execute(
        "UPDATE #{table} SET #{set_parts.join(', ')} WHERE id = #{ActiveRecord::Base.connection.quote(old_pk)}"
      )
    end

    puts "    Updated #{pk_mappings.size} records"
  end

  def update_active_storage_attachments(id_mappings)
    puts "  Updating active_storage_attachments..."

    # Map record types to their ID mappings
    record_type_mappings = {
      "Post" => id_mappings[:posts],
      "User" => id_mappings[:users]
    }

    attachment_mappings = id_mappings[:active_storage_attachments]
    blob_mappings = id_mappings[:active_storage_blobs]

    attachment_mappings.each do |old_pk, new_pk|
      # Get current values
      result = ActiveRecord::Base.connection.execute(
        "SELECT blob_id, record_type, record_id FROM active_storage_attachments WHERE id = #{ActiveRecord::Base.connection.quote(old_pk)}"
      ).first

      next unless result

      set_parts = [ "id = #{ActiveRecord::Base.connection.quote(new_pk)}" ]

      # Update blob_id
      old_blob_id = result["blob_id"]
      new_blob_id = blob_mappings[old_blob_id]
      set_parts << "blob_id = #{ActiveRecord::Base.connection.quote(new_blob_id)}" if new_blob_id

      # Update record_id (polymorphic)
      record_type = result["record_type"]
      old_record_id = result["record_id"]
      if record_type_mappings[record_type]
        new_record_id = record_type_mappings[record_type][old_record_id]
        set_parts << "record_id = #{ActiveRecord::Base.connection.quote(new_record_id)}" if new_record_id
      end

      ActiveRecord::Base.connection.execute(
        "UPDATE active_storage_attachments SET #{set_parts.join(', ')} WHERE id = #{ActiveRecord::Base.connection.quote(old_pk)}"
      )
    end

    puts "    Updated #{attachment_mappings.size} records"
  end

  def update_join_table(table, fk_mappings)
    puts "  Updating #{table}..."

    # Get all current rows
    rows = ActiveRecord::Base.connection.execute("SELECT * FROM #{table}").to_a

    # Delete all rows
    ActiveRecord::Base.connection.execute("DELETE FROM #{table}")

    # Insert with new IDs
    rows.each do |row|
      new_values = fk_mappings.map do |col, mapping|
        old_val = row[col.to_s]
        new_val = mapping[old_val] || old_val
        ActiveRecord::Base.connection.quote(new_val)
      end

      columns = fk_mappings.keys.join(", ")
      ActiveRecord::Base.connection.execute(
        "INSERT INTO #{table} (#{columns}) VALUES (#{new_values.join(', ')})"
      )
    end

    puts "    Updated #{rows.size} records"
  end

  def update_friendly_id_slugs(id_mappings)
    # Map sluggable types to their ID mappings
    type_mappings = {
      "Post" => id_mappings[:posts],
      "User" => id_mappings[:users],
      "Category" => id_mappings[:categories],
      "Tag" => id_mappings[:tags]
    }

    rows = ActiveRecord::Base.connection.execute("SELECT id, sluggable_type, sluggable_id FROM friendly_id_slugs").to_a

    rows.each do |row|
      sluggable_type = row["sluggable_type"]
      old_sluggable_id = row["sluggable_id"]

      next unless type_mappings[sluggable_type]

      new_sluggable_id = type_mappings[sluggable_type][old_sluggable_id]
      next unless new_sluggable_id

      ActiveRecord::Base.connection.execute(
        "UPDATE friendly_id_slugs SET sluggable_id = #{ActiveRecord::Base.connection.quote(new_sluggable_id)} WHERE id = #{row['id']}"
      )
    end

    puts "    Updated #{rows.size} slug references"
  end

  def update_image_variants(blob_mappings)
    return if blob_mappings.empty?

    # Get posts with image_variants
    posts = ActiveRecord::Base.connection.execute(
      "SELECT id, image_variants FROM posts WHERE image_variants IS NOT NULL AND image_variants != '{}' AND image_variants != 'null'"
    ).to_a

    updated_count = 0

    posts.each do |post|
      variants_json = post["image_variants"]
      next if variants_json.blank?

      begin
        variants = JSON.parse(variants_json)
        updated = false

        variants.each do |key, old_blob_id|
          if blob_mappings[old_blob_id]
            variants[key] = blob_mappings[old_blob_id]
            updated = true
          end
        end

        if updated
          ActiveRecord::Base.connection.execute(
            "UPDATE posts SET image_variants = #{ActiveRecord::Base.connection.quote(variants.to_json)} WHERE id = #{ActiveRecord::Base.connection.quote(post['id'])}"
          )
          updated_count += 1
        end
      rescue JSON::ParserError
        puts "    Warning: Could not parse image_variants for post #{post['id']}"
      end
    end

    puts "    Updated #{updated_count} posts with image_variants"
  end
end
