class UpdateGithubDataJob < ApplicationJob
  queue_as :default

  def perform(batch_size: 100)
    Rails.logger.info "Starting GitHub data update for all users..."
    
    users_updated = 0
    users_failed = 0
    
    User.find_each(batch_size: batch_size) do |user|
      next unless user.username.present?
      
      begin
        # Use the GithubDataFetcher service to update user data
        GithubDataFetcher.new(user).fetch_and_update!
        
        users_updated += 1
        Rails.logger.info "Successfully updated GitHub data for user: #{user.username}"
      rescue => e
        users_failed += 1
        Rails.logger.error "Failed to update GitHub data for user #{user.username}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      end
      
      # Add a small delay to avoid hitting rate limits
      # GitHub API allows 60 requests per hour for unauthenticated requests
      # or 5000 per hour for authenticated requests
      sleep 0.1
    end
    
    Rails.logger.info "GitHub data update completed. Updated: #{users_updated}, Failed: #{users_failed}"
    
    # Notify admin if there were failures
    if users_failed > 0 && defined?(NotifyAdminJob)
      NotifyAdminJob.perform_later(
        subject: "GitHub Data Update Report",
        message: "GitHub data update completed with #{users_failed} failures out of #{users_updated + users_failed} total users."
      )
    end
  end
end