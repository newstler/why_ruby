namespace :images do
  desc "Process existing images to WebP variants (run after migration 20250813204048)"
  task process_initial: :environment do
    puts "Processing existing images to WebP variants..."
    processed_count = 0
    error_count = 0
    skipped_count = 0

    Post.includes(featured_image_attachment: :blob).find_each do |post|
      next unless post.featured_image.attached?

      begin
        # Skip if already processed (has variants)
        if post.image_variants.present?
          skipped_count += 1
          print "S" # Skip indicator
          next
        end

        blob = post.featured_image.blob

        # Process the image to generate variants
        processor = ImageProcessor.new(blob)
        result = processor.process!

        if result[:success]
          post.update_columns(
            image_blur_data: result[:blur_data],
            image_variants: result[:variants]
          )
          processed_count += 1
          print "." # Progress indicator
        else
          Rails.logger.error "Failed to process image for Post ##{post.id}: #{result[:error]}"
          error_count += 1
          print "E"
        end

      rescue => e
        Rails.logger.error "Error processing Post ##{post.id}: #{e.message}"
        error_count += 1
        print "E"
      end
    end

    puts # New line after progress dots
    puts "\n" + "="*50
    puts "Initial image processing complete!"
    puts "Processed: #{processed_count} images"
    puts "Skipped (already processed): #{skipped_count} images"
    puts "Errors: #{error_count}" if error_count > 0
  end

  desc "Reprocess all post images with better quality settings"
  task reprocess_all: :environment do
    processed = 0
    failed = 0

    Post.includes(featured_image_attachment: :blob).find_each do |post|
      next unless post.featured_image.attached?

      begin
        print "Processing Post ##{post.id} (#{post.title[0..30]}...)... "

        # Clear existing variants
        if post.image_variants.present?
          post.image_variants.each do |_size, blob_id|
            ActiveStorage::Blob.find_by(id: blob_id)&.purge
          end
        end

        # Reprocess with new settings
        processor = ImageProcessor.new(post.featured_image)
        result = processor.process!

        if result[:success]
          post.update_columns(
            image_blur_data: result[:blur_data],
            image_variants: result[:variants]
          )
          processed += 1
          puts "✓"
        else
          failed += 1
          puts "✗ (#{result[:error]})"
        end
      rescue => e
        failed += 1
        puts "✗ (#{e.message})"
      end
    end

    puts "\n" + "="*50
    puts "Reprocessing complete!"
    puts "Successfully processed: #{processed}"
    puts "Failed: #{failed}"
  end

  desc "Check for broken images and list them"
  task check_broken: :environment do
    broken = []

    Post.includes(featured_image_attachment: :blob).find_each do |post|
      next unless post.featured_image.attached?
      next unless post.image_variants.present?

      post.image_variants.each do |size, blob_id|
        blob = ActiveStorage::Blob.find_by(id: blob_id)
        if blob.nil? || blob.byte_size == 0
          broken << "Post ##{post.id} - #{size} variant (blob_id: #{blob_id})"
        end
      end
    end

    if broken.any?
      puts "Found #{broken.size} broken image variants:"
      broken.each { |b| puts "  - #{b}" }
    else
      puts "No broken images found!"
    end
  end
end
