class Avo::Actions::MakeAdmin < Avo::BaseAction
  self.name = "Make Admin"
  self.visible = -> { true }
  self.message = "Are you sure you want to make these users admins?"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |user|
      user.update!(role: :admin)
    end

    succeed "Successfully made #{query.count} #{'user'.pluralize(query.count)} admin."
  end
end 