class GenerateSummaryJob < ApplicationJob
  queue_as :default

  def perform(post, force: false)
    post.generate_summary!(force: force)
  end
end
