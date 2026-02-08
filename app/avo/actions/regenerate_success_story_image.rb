class Avo::Actions::RegenerateSuccessStoryImage < Avo::BaseAction
  self.name = "Regenerate Success Story Image"
  self.visible = -> {
    return false unless view == :show

    resource.record.success_story? && resource.record.logo_svg.present?
  }

  def handle(query:, fields:, current_user:, resource:, **args)
    eligible_posts = query.select { |post| post.success_story? && post.logo_svg.present? }
    jobs = eligible_posts.map { |post| GenerateSuccessStoryImageJob.new(post, force: true) }
    ActiveJob.perform_all_later(jobs)

    succeed "Image regeneration queued for #{eligible_posts.size} #{"post".pluralize(eligible_posts.size)}"
  end
end
