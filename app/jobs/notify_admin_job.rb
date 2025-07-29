class NotifyAdminJob < ApplicationJob
  queue_as :urgent
  
  def perform(content)
    # Find all admin users
    admin_users = User.admins
    
    # For now, we'll just log the notification
    # In a real app, you'd send emails or notifications
    Rails.logger.info "ADMIN ALERT: Content '#{content.title}' (ID: #{content.id}) has been auto-hidden due to #{content.reports_count} reports."
    
    # TODO: Implement email notifications when mailer is configured
    # admin_users.each do |admin|
    #   AdminMailer.content_hidden_notification(admin, content).deliver_later
    # end
  end
end 