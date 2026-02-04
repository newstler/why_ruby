# frozen_string_literal: true

class NewsletterOpensController < ActionController::Base
  TRANSPARENT_GIF = "\x47\x49\x46\x38\x39\x61\x01\x00\x01\x00\x80\x00\x00\xff\xff\xff\x00\x00\x00\x21\xf9\x04\x01\x00\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x44\x01\x00\x3b".b

  def show
    data = Rails.application.message_verifier("newsletter_open").verify(params[:token])
    user = User.find(data["user_id"])
    user.record_newsletter_opened!(data["version"])
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    # Invalid token or missing user — silently ignore
  ensure
    send_data TRANSPARENT_GIF, type: "image/gif", disposition: "inline"
  end
end
