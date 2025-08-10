namespace :counter_caches do
  desc "Check and report on all counter cache fields"
  task check: :environment do
    puts "\n" + "="*80
    puts "COUNTER CACHE VALIDATION REPORT"
    puts "="*80

    errors = []
    warnings = []

    # Check users.published_posts_count
    puts "\n📊 Checking users.published_posts_count..."
    User.find_each do |user|
      actual_count = user.posts.published.count
      cached_count = user.published_posts_count
      
      if actual_count != cached_count
        error_msg = "User ##{user.id} (#{user.username}): cached=#{cached_count}, actual=#{actual_count}"
        errors << error_msg
        puts "  ❌ #{error_msg}"
      end
    end
    
    if errors.empty?
      puts "  ✅ All users.published_posts_count values are correct"
    end

    # Check users.published_comments_count
    puts "\n📊 Checking users.published_comments_count..."
    errors_comments = []
    User.find_each do |user|
      actual_count = user.comments.published.count
      cached_count = user.published_comments_count
      
      if actual_count != cached_count
        error_msg = "User ##{user.id} (#{user.username}): cached=#{cached_count}, actual=#{actual_count}"
        errors_comments << error_msg
        puts "  ❌ #{error_msg}"
      end
    end
    
    if errors_comments.empty?
      puts "  ✅ All users.published_comments_count values are correct"
    else
      errors.concat(errors_comments)
    end

    # Check posts.reports_count
    puts "\n📊 Checking posts.reports_count..."
    errors_reports = []
    Post.find_each do |post|
      actual_count = post.reports.count
      cached_count = post.reports_count
      
      if actual_count != cached_count
        error_msg = "Post ##{post.id} (#{post.title[0..30]}...): cached=#{cached_count}, actual=#{actual_count}"
        errors_reports << error_msg
        puts "  ❌ #{error_msg}"
      end
    end
    
    if errors_reports.empty?
      puts "  ✅ All posts.reports_count values are correct"
    else
      errors.concat(errors_reports)
    end

    # Summary
    puts "\n" + "="*80
    puts "SUMMARY"
    puts "="*80
    
    if errors.empty?
      puts "✅ All counter caches are correctly synchronized!"
    else
      puts "❌ Found #{errors.length} counter cache mismatches:"
      puts "   - #{errors.select { |e| e.include?('published_posts_count') }.count} for published_posts_count"
      puts "   - #{errors_comments.count} for published_comments_count"
      puts "   - #{errors_reports.count} for reports_count"
      puts "\nRun 'rails counter_caches:fix' to fix these issues."
    end
  end

  desc "Fix all counter cache mismatches"
  task fix: :environment do
    puts "\n" + "="*80
    puts "FIXING COUNTER CACHES"
    puts "="*80

    fixed_count = 0

    # Fix users.published_posts_count
    puts "\n🔧 Fixing users.published_posts_count..."
    User.find_each do |user|
      actual_count = user.posts.published.count
      if actual_count != user.published_posts_count
        user.update_column(:published_posts_count, actual_count)
        puts "  Fixed User ##{user.id} (#{user.username}): set to #{actual_count}"
        fixed_count += 1
      end
    end

    # Fix users.published_comments_count
    puts "\n🔧 Fixing users.published_comments_count..."
    User.find_each do |user|
      actual_count = user.comments.published.count
      if actual_count != user.published_comments_count
        user.update_column(:published_comments_count, actual_count)
        puts "  Fixed User ##{user.id} (#{user.username}): set to #{actual_count}"
        fixed_count += 1
      end
    end

    # Fix posts.reports_count - Rails should handle this with counter_cache: true
    puts "\n🔧 Fixing posts.reports_count..."
    Post.reset_counters(Post.pluck(:id), :reports)
    puts "  Reset all posts.reports_count using Rails reset_counters"

    puts "\n" + "="*80
    puts "✅ Fixed #{fixed_count} counter cache mismatches!"
    puts "Run 'rails counter_caches:check' to verify."
  end
end
