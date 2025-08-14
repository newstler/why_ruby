namespace :success_stories do
  desc "Generate PNG images for all success stories"
  task generate_images: :environment do
    success_stories = Post.success_stories.where.not(logo_svg: [ nil, "" ])

    puts "Found #{success_stories.count} success stories to process..."

    success_stories.find_each do |post|
      print "Processing '#{post.title}'... "

      begin
        SuccessStoryImageGenerator.new(post).generate!
        puts "✓"
      rescue => e
        puts "✗ Error: #{e.message}"
      end
    end

    puts "Done!"
  end

  desc "Queue image generation for all success stories (using background jobs)"
  task queue_image_generation: :environment do
    success_stories = Post.success_stories.where.not(logo_svg: [ nil, "" ])

    puts "Queueing image generation for #{success_stories.count} success stories..."

    success_stories.find_each do |post|
      GenerateSuccessStoryImageJob.perform_later(post, force: true)
      print "."
    end

    puts "\nDone! Jobs queued."
  end

  desc "Clear all generated PNG images for success stories"
  task clear_images: :environment do
    count = 0
    Post.success_stories.find_each do |post|
      if post.featured_image.attached?
        post.featured_image.purge
        count += 1
      end
    end
    puts "Cleared #{count} PNG images for success stories"
  end

  desc "Regenerate images for success stories missing them"
  task regenerate_missing: :environment do
    missing = Post.success_stories
                  .where.not(logo_svg: [ nil, "" ])
                  .left_joins(:featured_image_attachment)
                  .where(active_storage_attachments: { id: nil })

    puts "Found #{missing.count} success stories missing images..."

    missing.find_each do |post|
      GenerateSuccessStoryImageJob.perform_later(post, force: false)
      print "."
    end

    puts "\nDone! Jobs queued."
  end

  desc "Regenerate all success story images (force)"
  task regenerate_images: :environment do
    success_stories = Post.success_stories.where.not(logo_svg: [ nil, "" ])

    puts "Regenerating images for #{success_stories.count} success stories..."

    success_stories.find_each do |post|
      print "Processing '#{post.title}'... "

      begin
        # Purge existing image if present
        post.featured_image.purge if post.featured_image.attached?

        # Generate new image
        SuccessStoryImageGenerator.new(post).generate!
        puts "✓"
      rescue => e
        puts "✗ Error: #{e.message}"
      end
    end

    puts "Done!"
  end
end
