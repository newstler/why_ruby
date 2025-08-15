namespace :images do
  desc "Update all post images to use new variant names (tile, post, og)"
  task update_variants: :environment do
    posts_with_images = Post.where.not(image_variants: nil)
    total = posts_with_images.count

    puts "Found #{total} posts with image variants to update"

    posts_with_images.find_each.with_index do |post, index|
      next unless post.featured_image.attached?

      # Map old variant names to new ones
      old_variants = post.image_variants || {}
      new_variants = {}

      # Map thumb -> tile, medium -> post, large -> og (but regenerate og to be 1200x630)
      new_variants["tile"] = old_variants["thumb"] if old_variants["thumb"]
      new_variants["post"] = old_variants["medium"] if old_variants["medium"]

      # For og variant, we need to regenerate since dimensions changed from 1920x1080 to 1200x630
      # So we'll trigger a full reprocess

      print "Processing post #{index + 1}/#{total} (#{post.title[0..30]}...)... "

      # Reprocess the image with new variants
      processor = ImageProcessor.new(post.featured_image)
      result = processor.process!

      if result[:success]
        post.update_columns(image_variants: result[:variants])
        puts "✓"
      else
        puts "✗ (#{result[:error]})"
      end
    end

    puts "\nDone! All image variants have been updated."
  end

  desc "Reprocess images for posts missing the og variant"
  task ensure_og_variant: :environment do
    posts_needing_og = Post.joins(:active_storage_attachments)
                           .where("image_variants IS NOT NULL")
                           .where("NOT (image_variants ? 'og')")

    total = posts_needing_og.count
    puts "Found #{total} posts missing the og variant"

    posts_needing_og.find_each.with_index do |post, index|
      next unless post.featured_image.attached?

      print "Processing post #{index + 1}/#{total} (#{post.title[0..30]}...)... "

      processor = ImageProcessor.new(post.featured_image)
      result = processor.process!

      if result[:success]
        post.update_columns(image_variants: result[:variants])
        puts "✓"
      else
        puts "✗ (#{result[:error]})"
      end
    end

    puts "\nDone! All posts now have og variants."
  end
end
