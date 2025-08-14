class Avo::Actions::RegenerateSuccessStoryImage < Avo::BaseAction
  self.name = "Regenerate Success Story Image"
  self.visible = -> {
    return false unless view == :show

    resource.record.success_story? && resource.record.logo_svg.present?
  }

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |post|
      next unless post.success_story? && post.logo_svg.present?

      # Force regenerate the image
      GenerateSuccessStoryImageJob.perform_later(post, force: true)
    end

    succeed "Image regeneration queued for #{query.count} #{"post".pluralize(query.count)}"
  end
end
