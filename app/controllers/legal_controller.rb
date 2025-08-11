class LegalController < ApplicationController
  include ApplicationHelper

  def show
    # Sanitize the page parameter to prevent path traversal
    page_name = params[:page].to_s.gsub(/[^a-z0-9_-]/i, "")

    # Whitelist of allowed legal pages
    allowed_pages = %w[privacy_policy terms_of_service cookie_policy legal_notice]

    unless allowed_pages.include?(page_name)
      redirect_to root_path, alert: "Page not found"
      return
    end

    filename = "#{page_name}.md"
    file_path = Rails.root.join("app", "content", "legal", filename)

    if File.exist?(file_path)
      markdown_content = File.read(file_path)
      @content = markdown_to_html(markdown_content)
    else
      redirect_to root_path, alert: "Page not found"
    end
  end
end
