class UpdateGithubDataJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 5

  def perform
    Rails.logger.info "Starting GitHub data update using GraphQL batch fetching..."

    total_updated = 0
    total_failed = 0
    all_errors = []

    User.where.not(username: [ nil, "" ]).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      results = User.batch_sync_github_data!(batch)

      total_updated += results[:updated]
      total_failed += results[:failed]
      all_errors.concat(results[:errors]) if results[:errors].present?

      sleep 0.5
    end

    Rails.logger.info "GitHub data update completed. Updated: #{total_updated}, Failed: #{total_failed}"

    if all_errors.any?
      Rails.logger.warn "Errors encountered: #{all_errors.first(10).join(', ')}#{all_errors.size > 10 ? '...' : ''}"
    end
  end
end
