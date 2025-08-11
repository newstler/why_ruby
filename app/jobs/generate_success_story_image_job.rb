class GenerateSuccessStoryImageJob < ApplicationJob
  queue_as :default

  def perform(post)
    # Only process success stories with logos
    return unless post.success_story? && post.logo_svg.present?

    # Skip if already has a generated image (unless forced)
    return if post.logo_png_base64.present?

    # Generate the image
    SuccessStoryImageGenerator.new(post).generate!

    Rails.logger.info "Generated success story image for post #{post.id}"
  rescue => e
    Rails.logger.error "Failed to generate success story image for post #{post.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
