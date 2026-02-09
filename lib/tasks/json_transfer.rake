# frozen_string_literal: true

namespace :db do
  desc "Export all data to JSON"
  task export_json: :environment do
    data = {
      users: User.all.as_json,
      categories: Category.all.as_json,
      tags: Tag.all.as_json,
      posts: Post.all.as_json,
      comments: Comment.all.as_json,
      reports: Report.all.as_json,
      posts_tags: ActiveRecord::Base.connection.execute("SELECT * FROM posts_tags").to_a,
      friendly_id_slugs: FriendlyId::Slug.all.as_json,
      active_storage_blobs: ActiveStorage::Blob.all.as_json,
      active_storage_attachments: ActiveStorage::Attachment.all.as_json
    }

    File.write("data_export.json", JSON.pretty_generate(data))
    puts "Exported to data_export.json"
  end

  desc "Import all data from JSON with UUIDv7 IDs"
  task import_json: :environment do
    require "securerandom"

    data = JSON.parse(File.read("data_export.json"))
    id_map = {}

    def generate_uuid7
      timestamp_ms = (Time.now.to_f * 1000).to_i
      timestamp_hex = format("%012x", timestamp_ms)
      random_a = SecureRandom.hex(2)
      random_b = SecureRandom.hex(8)
      version_and_random = "7" + random_a[1..3]
      variant_and_random = format("%x", (random_b[0].to_i(16) & 0x3) | 0x8) + random_b[1..15]
      "#{timestamp_hex[0..7]}-#{timestamp_hex[8..11]}-#{version_and_random}-#{variant_and_random[0..3]}-#{variant_and_random[4..15]}"
    end

    ActiveRecord::Base.transaction do
      # Build ID mappings first
      %w[users categories tags posts active_storage_blobs].each do |table|
        id_map[table] = {}
        data[table].each { |r| id_map[table][r["id"]] = generate_uuid7 }
      end

      # Import users
      puts "Importing users..."
      data["users"].each do |u|
        User.create!(u.except("id", "created_at", "updated_at").merge(
          "id" => id_map["users"][u["id"]]
        ))
      end

      # Import categories
      puts "Importing categories..."
      data["categories"].each do |c|
        Category.create!(c.except("id", "created_at", "updated_at").merge(
          "id" => id_map["categories"][c["id"]]
        ))
      end

      # Import tags
      puts "Importing tags..."
      data["tags"].each do |t|
        Tag.create!(t.except("id", "created_at", "updated_at").merge(
          "id" => id_map["tags"][t["id"]]
        ))
      end

      # Import blobs
      puts "Importing blobs..."
      data["active_storage_blobs"].each do |b|
        ActiveStorage::Blob.create!(b.except("id", "created_at").merge(
          "id" => id_map["active_storage_blobs"][b["id"]]
        ))
      end

      # Import posts with FK mappings
      puts "Importing posts..."
      data["posts"].each do |p|
        # Update image_variants JSON
        variants = p["image_variants"]
        if variants.is_a?(Hash)
          variants.transform_values! { |v| id_map["active_storage_blobs"][v] || v }
        end

        Post.create!(p.except("id", "created_at", "updated_at").merge(
          "id" => id_map["posts"][p["id"]] ||= generate_uuid7,
          "user_id" => id_map["users"][p["user_id"]],
          "category_id" => id_map["categories"][p["category_id"]],
          "image_variants" => variants
        ))
      end

      # Import attachments
      puts "Importing attachments..."
      data["active_storage_attachments"].each do |a|
        record_id = case a["record_type"]
        when "Post" then id_map["posts"][a["record_id"]]
        when "User" then id_map["users"][a["record_id"]]
        else a["record_id"]
        end

        ActiveStorage::Attachment.create!(a.except("id", "created_at").merge(
          "id" => generate_uuid7,
          "blob_id" => id_map["active_storage_blobs"][a["blob_id"]],
          "record_id" => record_id
        ))
      end

      # Import posts_tags
      puts "Importing posts_tags..."
      data["posts_tags"].each do |pt|
        ActiveRecord::Base.connection.execute(
          "INSERT INTO posts_tags (post_id, tag_id) VALUES (#{ActiveRecord::Base.connection.quote(id_map['posts'][pt['post_id']])}, #{ActiveRecord::Base.connection.quote(id_map['tags'][pt['tag_id']])})"
        )
      end

      # Import slugs
      puts "Importing slugs..."
      data["friendly_id_slugs"].each do |s|
        new_sluggable_id = case s["sluggable_type"]
        when "Post" then id_map["posts"][s["sluggable_id"]]
        when "User" then id_map["users"][s["sluggable_id"]]
        when "Category" then id_map["categories"][s["sluggable_id"]]
        when "Tag" then id_map["tags"][s["sluggable_id"]]
        else s["sluggable_id"]
        end

        FriendlyId::Slug.create!(s.except("id", "created_at").merge(
          "sluggable_id" => new_sluggable_id
        ))
      end
    end

    puts "Import complete!"
  end
end
