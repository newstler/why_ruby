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

  desc "Clear all generated PNG images for success stories"
  task clear_images: :environment do
    Post.success_stories.update_all(logo_png_base64: nil)
    puts "Cleared all PNG images for success stories"
  end
end
