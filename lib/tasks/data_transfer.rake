# frozen_string_literal: true

namespace :db do
  namespace :transfer do
    desc "Verify database before transformation (run after copying from old server)"
    task verify_before: :environment do
      puts "=" * 60
      puts "Pre-Transformation Verification"
      puts "=" * 60

      tables = %w[users categories tags posts comments reports testimonials admins
                  active_storage_blobs active_storage_attachments active_storage_variant_records
                  posts_tags friendly_id_slugs]

      tables.each do |table|
        count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM #{table}").first["count"]
        sample_id = ActiveRecord::Base.connection.execute("SELECT id FROM #{table} LIMIT 1").first&.dig("id")
        puts "  #{table.ljust(30)} #{count.to_s.rjust(6)} records  (sample ID: #{sample_id || 'none'})"
      end

      puts "\n" + "=" * 60
      puts "Save these counts to verify after transformation!"
      puts "=" * 60
    end

    desc "Verify database after transformation"
    task verify_after: :environment do
      puts "=" * 60
      puts "Post-Transformation Verification"
      puts "=" * 60

      tables = %w[users categories tags posts comments reports testimonials admins
                  active_storage_blobs active_storage_attachments active_storage_variant_records
                  posts_tags friendly_id_slugs]

      uuid7_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

      tables.each do |table|
        count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM #{table}").first["count"]

        # Check if IDs are UUIDv7 format (skip join tables and friendly_id_slugs)
        if %w[posts_tags friendly_id_slugs].include?(table)
          puts "  #{table.ljust(30)} #{count.to_s.rjust(6)} records"
        else
          sample = ActiveRecord::Base.connection.execute("SELECT id FROM #{table} LIMIT 1").first
          if sample
            id_format = sample["id"].match?(uuid7_regex) ? "✓ UUIDv7" : "✗ NOT UUIDv7"
            puts "  #{table.ljust(30)} #{count.to_s.rjust(6)} records  #{id_format}"
          else
            puts "  #{table.ljust(30)} #{count.to_s.rjust(6)} records"
          end
        end
      end

      # Verify foreign key integrity
      puts "\n" + "-" * 60
      puts "Foreign Key Integrity Checks:"
      puts "-" * 60

      checks = [
        [ "posts.user_id", "SELECT COUNT(*) FROM posts WHERE user_id NOT IN (SELECT id FROM users)" ],
        [ "posts.category_id", "SELECT COUNT(*) FROM posts WHERE category_id NOT IN (SELECT id FROM categories)" ],
        [ "comments.user_id", "SELECT COUNT(*) FROM comments WHERE user_id NOT IN (SELECT id FROM users)" ],
        [ "comments.post_id", "SELECT COUNT(*) FROM comments WHERE post_id NOT IN (SELECT id FROM posts)" ],
        [ "reports.user_id", "SELECT COUNT(*) FROM reports WHERE user_id NOT IN (SELECT id FROM users)" ],
        [ "reports.post_id", "SELECT COUNT(*) FROM reports WHERE post_id NOT IN (SELECT id FROM posts)" ],
        [ "testimonials.user_id", "SELECT COUNT(*) FROM testimonials WHERE user_id NOT IN (SELECT id FROM users)" ],
        [ "posts_tags.post_id", "SELECT COUNT(*) FROM posts_tags WHERE post_id NOT IN (SELECT id FROM posts)" ],
        [ "posts_tags.tag_id", "SELECT COUNT(*) FROM posts_tags WHERE tag_id NOT IN (SELECT id FROM tags)" ],
        [ "attachments.blob_id", "SELECT COUNT(*) FROM active_storage_attachments WHERE blob_id NOT IN (SELECT id FROM active_storage_blobs)" ],
        [ "variants.blob_id", "SELECT COUNT(*) FROM active_storage_variant_records WHERE blob_id NOT IN (SELECT id FROM active_storage_blobs)" ]
      ]

      all_ok = true
      checks.each do |name, query|
        orphans = ActiveRecord::Base.connection.execute(query).first["COUNT(*)"]
        status = orphans.zero? ? "✓" : "✗ #{orphans} orphans"
        puts "  #{name.ljust(25)} #{status}"
        all_ok = false if orphans > 0
      end

      puts "\n" + "=" * 60
      if all_ok
        puts "All checks passed! Database is ready."
      else
        puts "WARNING: Some foreign key checks failed!"
      end
      puts "=" * 60
    end

    desc "Full data transfer workflow"
    task full: :environment do
      puts <<~INSTRUCTIONS
        ╔══════════════════════════════════════════════════════════════╗
        ║           WhyRuby Data Transfer Instructions                 ║
        ╚══════════════════════════════════════════════════════════════╝

        Step 1: Backup current database (if any)
        ─────────────────────────────────────────
        cp storage/production.sqlite3 storage/production.sqlite3.backup.$(date +%Y%m%d)

        Step 2: Copy database from old server
        ─────────────────────────────────────────
        scp user@whyruby.info:/path/to/storage/production.sqlite3 ./storage/

        Step 3: Copy ActiveStorage files from old server
        ─────────────────────────────────────────
        rsync -avz user@whyruby.info:/path/to/storage/ ./storage/ --exclude='*.sqlite3'

        Step 4: Verify pre-transformation state
        ─────────────────────────────────────────
        rails db:transfer:verify_before RAILS_ENV=production

        Step 5: Transform ULID to UUIDv7
        ─────────────────────────────────────────
        rails db:transform_ulid_to_uuid7 RAILS_ENV=production

        Step 6: Verify post-transformation state
        ─────────────────────────────────────────
        rails db:transfer:verify_after RAILS_ENV=production

        Step 7: Test the application
        ─────────────────────────────────────────
        - Start server: bin/dev
        - Test user login
        - Test viewing posts
        - Test image loading
        - Test FriendlyId slugs

      INSTRUCTIONS
    end
  end
end
