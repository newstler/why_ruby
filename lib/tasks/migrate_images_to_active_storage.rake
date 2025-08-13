namespace :posts do
  desc "Migrate existing post images to ActiveStorage"
  task migrate_images_to_active_storage: :environment do
    require "open-uri"
    require "base64"

    puts "Starting migration of post images to ActiveStorage..."

    # Track statistics
    success_count = 0
    failure_count = 0
    skipped_count = 0

    # Process all posts
    Post.find_each do |post|
      begin
        # Skip if already migrated
        if post.images_migrated
          skipped_count += 1
          next
        end

        changed = false

        # Migrate success story PNG images
        if post.success_story? && post.logo_png_base64.present? && !post.og_image.attached?
          puts "  Migrating success story image for post ##{post.id} (#{post.title})"

          # Extract base64 data
          if post.logo_png_base64.match(/^data:image\/png;base64,(.+)$/)
            base64_data = $1
            image_data = Base64.decode64(base64_data)

            post.og_image.attach(
              io: StringIO.new(image_data),
              filename: "#{post.slug}-og.png",
              content_type: "image/png"
            )
            changed = true
            puts "    ✓ Success story image migrated"
          end
        end

        # Migrate regular post images from URLs
        if post.title_image_url.present? && !post.featured_image.attached?
          puts "  Migrating featured image for post ##{post.id} (#{post.title})"

          begin
            # Fetch image from URL
            image_data = URI.open(post.title_image_url)
            filename = File.basename(URI.parse(post.title_image_url).path).presence || "image.jpg"

            post.featured_image.attach(
              io: image_data,
              filename: filename
            )
            changed = true
            puts "    ✓ Featured image migrated from URL"
          rescue => e
            puts "    ✗ Failed to fetch image from URL: #{e.message}"
            failure_count += 1
            next
          end
        end

        # Mark as migrated if any changes were made
        if changed
          post.update_column(:images_migrated, true)
          success_count += 1
        else
          skipped_count += 1
        end

      rescue => e
        puts "  ✗ Error processing post ##{post.id}: #{e.message}"
        failure_count += 1
      end
    end

    puts "\nMigration complete!"
    puts "  Successfully migrated: #{success_count} posts"
    puts "  Skipped (already migrated or no images): #{skipped_count} posts"
    puts "  Failed: #{failure_count} posts"

    if failure_count > 0
      puts "\nPlease review failed posts and retry if needed."
    end
  end

  desc "Verify image migration status"
  task verify_image_migration: :environment do
    puts "Verifying image migration status..."

    total_posts = Post.count
    migrated_posts = Post.where(images_migrated: true).count

    posts_with_base64 = Post.where.not(logo_png_base64: nil).count
    posts_with_url = Post.where.not(title_image_url: nil).count
    posts_with_og_image = Post.joins(:og_image_attachment).distinct.count
    posts_with_featured_image = Post.joins(:featured_image_attachment).distinct.count

    puts "\nMigration Status:"
    puts "  Total posts: #{total_posts}"
    puts "  Marked as migrated: #{migrated_posts}"
    puts "\nOld fields (to be removed):"
    puts "  Posts with base64 PNG: #{posts_with_base64}"
    puts "  Posts with title_image_url: #{posts_with_url}"
    puts "\nNew ActiveStorage attachments:"
    puts "  Posts with og_image: #{posts_with_og_image}"
    puts "  Posts with featured_image: #{posts_with_featured_image}"

    # Check for posts that might need migration
    unmigrated_with_data = Post.where(images_migrated: false)
                                .where("logo_png_base64 IS NOT NULL OR title_image_url IS NOT NULL")
                                .count

    if unmigrated_with_data > 0
      puts "\n⚠️  #{unmigrated_with_data} posts have image data but are not marked as migrated!"
      puts "Run 'rails posts:migrate_images_to_active_storage' to migrate them."
    else
      puts "\n✓ All posts with image data have been migrated!"
    end
  end
end
