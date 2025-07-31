namespace :summaries do
  desc "Generate AI summaries for posts that don't have them"
  task generate: :environment do
    posts_without_summary = Post.published.where(summary: [nil, ""])
    total_count = posts_without_summary.count
    
    puts "Found #{total_count} published posts without summaries"
    
    if total_count == 0
      puts "All posts already have summaries!"
      next
    end
    
    processed = 0
    failed = 0
    
    posts_without_summary.find_each.with_index do |post, index|
      print "\rProcessing post #{index + 1}/#{total_count}: '#{post.title.truncate(50)}'"
      
      begin
        GenerateSummaryJob.perform_now(post)
        post.reload
        
        if post.summary.present?
          processed += 1
        else
          failed += 1
          puts "\n⚠️  Failed to generate summary for post ##{post.id}: '#{post.title}'"
        end
      rescue => e
        failed += 1
        puts "\n❌ Error processing post ##{post.id}: #{e.message}"
      end
      
      # Rate limiting to avoid hitting API limits
      sleep(1) if index < total_count - 1
    end
    
    puts "\n\nSummary generation complete!"
    puts "✅ Successfully generated: #{processed} summaries"
    puts "❌ Failed: #{failed} posts" if failed > 0
  end
  
  desc "Regenerate all AI summaries (overwrites existing ones)"
  task regenerate_all: :environment do
    if ENV['CONFIRM'] != 'yes'
      puts "⚠️  This will overwrite all existing summaries!"
      puts "Run with CONFIRM=yes to proceed"
      next
    end
    
    posts = Post.published
    total_count = posts.count
    
    puts "Regenerating summaries for #{total_count} published posts"
    
    processed = 0
    failed = 0
    
    posts.find_each.with_index do |post, index|
      print "\rProcessing post #{index + 1}/#{total_count}: '#{post.title.truncate(50)}'"
      
      begin
        # Clear existing summary
        post.update_column(:summary, nil)
        
        GenerateSummaryJob.perform_now(post)
        post.reload
        
        if post.summary.present?
          processed += 1
        else
          failed += 1
          puts "\n⚠️  Failed to generate summary for post ##{post.id}: '#{post.title}'"
        end
      rescue => e
        failed += 1
        puts "\n❌ Error processing post ##{post.id}: #{e.message}"
      end
      
      # Rate limiting to avoid hitting API limits
      sleep(1) if index < total_count - 1
    end
    
    puts "\n\nSummary regeneration complete!"
    puts "✅ Successfully generated: #{processed} summaries"
    puts "❌ Failed: #{failed} posts" if failed > 0
  end
  
  desc "Test AI summary generation with a specific post"
  task :test, [:post_id] => :environment do |t, args|
    unless args[:post_id]
      puts "Usage: rails summaries:test[POST_ID]"
      next
    end
    
    post = Post.find_by(id: args[:post_id])
    
    unless post
      puts "❌ Post with ID #{args[:post_id]} not found"
      next
    end
    
    puts "Testing summary generation for post ##{post.id}: '#{post.title}'"
    puts "Current summary: #{post.summary.present? ? post.summary : '(none)'}"
    puts "\nGenerating new summary..."
    
    # Clear existing summary for testing
    post.update_column(:summary, nil)
    
    GenerateSummaryJob.perform_now(post)
    post.reload
    
    if post.summary.present?
      puts "\n✅ Summary generated successfully:"
      puts "-" * 50
      puts post.summary
      puts "-" * 50
    else
      puts "\n❌ Failed to generate summary"
    end
  end
end 