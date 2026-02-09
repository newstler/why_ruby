class UpdateGithubDataJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 5 # Server-side Ruby filtering means fewer repos returned

  def perform
    Rails.logger.info "Starting GitHub data update using GraphQL batch fetching..."

    total_updated = 0
    total_failed = 0
    all_errors = []

    User.where.not(username: [ nil, "" ]).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      Rails.logger.info "Processing batch of #{batch.size} users..."

      results = GithubDataFetcher.batch_fetch_and_update!(batch)

      total_updated += results[:updated]
      total_failed += results[:failed]
      all_errors.concat(results[:errors]) if results[:errors].present?

      Rails.logger.info "Batch complete: #{results[:updated]} updated, #{results[:failed]} failed"

      # Brief pause between batches to be respectful of API
      sleep 0.5
    end

    Rails.logger.info "GitHub data update completed. Updated: #{total_updated}, Failed: #{total_failed}"

    if all_errors.any?
      Rails.logger.warn "Errors encountered: #{all_errors.first(10).join(', ')}#{all_errors.size > 10 ? '...' : ''}"
    end

    # Notify admin if there were significant failures
    if total_failed > 5 && defined?(NotifyAdminJob)
      NotifyAdminJob.perform_later(
        subject: "GitHub Data Update Report",
        message: "GitHub data update completed with #{total_failed} failures out of #{total_updated + total_failed} total users."
      )
    end
  end
end
