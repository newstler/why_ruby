class LegalController < ApplicationController
  include ApplicationHelper

  def show
    filename = "#{params[:page]}.md"
    file_path = Rails.root.join("app", "content", "legal", filename)

    if File.exist?(file_path)
      markdown_content = File.read(file_path)
      @content = markdown_to_html(markdown_content)
    else
      redirect_to root_path, alert: "Page not found"
    end
  end
end
