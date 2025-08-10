namespace :friendly_id do
  desc "Generate slugs for existing records (useful for maintenance or after data imports)"
  task generate_slugs: :environment do
    # NOTE: Slug generation is now handled automatically in migrations.
    # This task is useful for:
    # - Regenerating slugs after bulk data imports
    # - Fixing broken slugs
    # - Testing slug generation in development
    
    puts "Generating slugs for Posts..."
    Post.find_each do |post|
      post.slug = nil
      post.save!(validate: false)
      print "."
    end
    puts " Done!"
    
    puts "Generating slugs for Categories..."
    Category.find_each do |category|
      category.slug = nil
      category.save!(validate: false)
      print "."
    end
    puts " Done!"
    
    puts "Generating slugs for Tags..."
    Tag.find_each do |tag|
      tag.slug = nil
      tag.save!(validate: false)
      print "."
    end
    puts " Done!"
    
    puts "Generating slugs for Users..."
    User.find_each do |user|
      user.slug = nil
      user.save!(validate: false)
      print "."
    end
    puts " Done!"
    
    puts "\nAll slugs generated successfully!"
  end
  
  desc "Find and fix duplicate slugs"
  task fix_duplicates: :environment do
    puts "Checking for duplicate slugs..."
    
    # Check Posts
    duplicate_post_slugs = Post.group(:slug).having("COUNT(*) > 1").pluck(:slug)
    if duplicate_post_slugs.any?
      puts "Found #{duplicate_post_slugs.count} duplicate post slugs. Fixing..."
      duplicate_post_slugs.each do |slug|
        Post.where(slug: slug).order(:created_at).offset(1).each do |post|
          post.slug = nil
          post.save!(validate: false)
        end
      end
    end
    
    # Check Categories
    duplicate_category_slugs = Category.group(:slug).having("COUNT(*) > 1").pluck(:slug)
    if duplicate_category_slugs.any?
      puts "Found #{duplicate_category_slugs.count} duplicate category slugs. Fixing..."
      duplicate_category_slugs.each do |slug|
        Category.where(slug: slug).order(:created_at).offset(1).each do |category|
          category.slug = nil
          category.save!(validate: false)
        end
      end
    end
    
    # Check Tags
    duplicate_tag_slugs = Tag.group(:slug).having("COUNT(*) > 1").pluck(:slug)
    if duplicate_tag_slugs.any?
      puts "Found #{duplicate_tag_slugs.count} duplicate tag slugs. Fixing..."
      duplicate_tag_slugs.each do |slug|
        Tag.where(slug: slug).order(:created_at).offset(1).each do |tag|
          tag.slug = nil
          tag.save!(validate: false)
        end
      end
    end
    
    # Check Users
    duplicate_user_slugs = User.group(:slug).having("COUNT(*) > 1").pluck(:slug)
    if duplicate_user_slugs.any?
      puts "Found #{duplicate_user_slugs.count} duplicate user slugs. Fixing..."
      duplicate_user_slugs.each do |slug|
        User.where(slug: slug).order(:created_at).offset(1).each do |user|
          user.slug = nil
          user.save!(validate: false)
        end
      end
    end
    
    puts "Duplicate check complete!"
  end
end