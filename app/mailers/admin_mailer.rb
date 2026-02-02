# frozen_string_literal: true

class AdminMailer < ApplicationMailer
  def post_hidden_notification(admin, post)
    @admin = admin
    @post = post
    mail(to: @admin.email, subject: "Post auto-hidden: #{post.title}")
  end
end
