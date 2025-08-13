namespace :images do
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
