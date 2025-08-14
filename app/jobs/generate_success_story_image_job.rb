class GenerateSuccessStoryImageJob < ApplicationJob
  queue_as :default

  def perform(post, force: false)
    Rails.logger.info "GenerateSuccessStoryImageJob started for post #{post.id}: force=#{force}, has_image=#{post.featured_image.attached?}"

    # Only process success stories with logos
    return unless post.success_story? && post.logo_svg.present?

    # Skip if already has a generated image (unless forced)
    should_regenerate = force || !post.featured_image.attached?

    unless should_regenerate
      Rails.logger.info "Skipping image generation for post #{post.id} - image already exists (force=#{force})"
      return
    end

    # Purge existing image if we're regenerating
    if force && post.featured_image.attached?
      Rails.logger.info "Purging existing image for post #{post.id} before regeneration"
      post.featured_image.purge
    end

    # Generate the image
    SuccessStoryImageGenerator.new(post).generate!

    Rails.logger.info "Generated success story image for post #{post.id}"
  rescue => e
    Rails.logger.error "Failed to generate success story image for post #{post.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
