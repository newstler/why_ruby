class AddImageProcessingFieldsToPosts < ActiveRecord::Migration[8.0]
  def up
    # Add new columns for image processing
    add_column :posts, :image_blur_data, :text
    add_column :posts, :image_variants, :json

    # Process existing images
    say_with_time "Processing existing images to WebP variants..." do
      process_existing_images
    end
  end

  def down
    remove_column :posts, :image_blur_data
    remove_column :posts, :image_variants

    # Note: We don't restore original images on rollback
    # The featured_image attachment remains intact
  end

  private

  def process_existing_images
    processed_count = 0
    error_count = 0

    Post.includes(featured_image_attachment: :blob).find_each do |post|
      next unless post.featured_image.attached?

      begin
        # Skip if already processed (has variants)
        next if post.image_variants.present?

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
    puts "Processed #{processed_count} images successfully"
    puts "Encountered #{error_count} errors" if error_count > 0
  end
end
