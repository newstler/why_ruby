# frozen_string_literal: true

class NewsletterUnsubscribesController < ApplicationController
  def show
    @user = User.find_signed(params[:token], purpose: :newsletter_unsubscribe)

    if @user
      @user.update!(unsubscribed_from_newsletter: true)
      @success = true
    else
      @success = false
    end
  end
end
