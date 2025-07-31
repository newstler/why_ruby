class Avo::Actions::RegenerateSummary < Avo::BaseAction
  self.name = "Regenerate AI Summary"
  self.visible = -> { true }
  self.message = "This will replace the existing summary with a new AI-generated one."
  
  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |post|
      # Clear existing summary
      post.update_column(:summary, nil)
      # Queue summary regeneration
      GenerateSummaryJob.perform_later(post)
    end
    
    succeed "AI summary regeneration queued for #{query.count} #{'post'.pluralize(query.count)}."
  end
end 