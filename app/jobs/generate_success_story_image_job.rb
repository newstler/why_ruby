class GenerateSuccessStoryImageJob < ApplicationJob
  queue_as :default

  def perform(post, force: false)
    post.generate_og_image!(force: force)
  rescue => e
    Rails.logger.error "Failed to generate success story image for post #{post.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
