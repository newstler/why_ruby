class Avo::Actions::MakeAdmin < Avo::BaseAction
  self.name = "Make Admin"
  self.visible = -> { true }
  self.message = "Are you sure you want to make these users admins?"

  def handle(query:, fields:, current_user:, resource:, **args)
    # Ensure query is always a collection
    users = query.is_a?(ActiveRecord::Relation) ? query : [query]
    
    users.each do |user|
      user.update!(role: :admin)
    end

    count = users.is_a?(Array) ? users.size : users.count
    succeed "Successfully made #{count} #{'user'.pluralize(count)} admin."
  end
end 