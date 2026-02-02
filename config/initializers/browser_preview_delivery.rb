# frozen_string_literal: true

# Custom delivery method that opens emails in the browser for development testing.
# Writes the email to a temp file and opens it in the default browser.

class BrowserPreviewDelivery
  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    tmp = Tempfile.new([ "email_preview", ".html" ])
    tmp.write(mail.html_part&.body&.decoded || mail.body.decoded)
    tmp.close
    system("open", tmp.path)
  end
end

ActionMailer::Base.add_delivery_method :browser_preview, BrowserPreviewDelivery
