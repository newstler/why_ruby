class NotifyAdminJob < ApplicationJob
  queue_as :urgent
  
  def perform(post)
    # Find all admin users
    admin_users = User.admins
    
    # For now, we'll just log the notification
    # In a real app, you'd send emails or notifications
    Rails.logger.info "ADMIN ALERT: Post '#{post.title}' (ID: #{post.id}) has been auto-hidden due to #{post.reports_count} reports."
    
    # TODO: Implement email notifications when mailer is configured
    # admin_users.each do |admin|
    #   AdminMailer.post_hidden_notification(admin, post).deliver_later
    # end
  end
end 