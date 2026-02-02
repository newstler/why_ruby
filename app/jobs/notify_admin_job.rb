class NotifyAdminJob < ApplicationJob
  queue_as :urgent

  def perform(post)
    admin_users = User.admins

    Rails.logger.info "ADMIN ALERT: Post '#{post.title}' (ID: #{post.id}) has been auto-hidden due to #{post.reports_count} reports."

    admin_users.each do |admin|
      AdminMailer.post_hidden_notification(admin, post).deliver_later
    end
  end
end
