class Avo::Actions::RegenerateSummary < Avo::BaseAction
  self.name = "Regenerate AI Summary"
  self.visible = -> { true }
  self.message = "This will replace the existing summary with a new AI-generated one."
  
  def handle(query:, fields:, current_user:, resource:, **args)
    # Ensure query is always a collection
    posts = case query
            when ActiveRecord::Relation
              query
            when Array
              query  # Already a collection from our patch
            else
              [query]  # Single record, wrap in array
            end
    
    posts.each do |post|
      # Queue summary regeneration with force flag to override existing summary
      GenerateSummaryJob.perform_later(post, force: true)
    end
    
    count = posts.is_a?(Array) ? posts.size : posts.count
    succeed "AI summary regeneration queued for #{count} #{'post'.pluralize(count)}."
  end
end 