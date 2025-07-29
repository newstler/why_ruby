class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_content
  before_action :ensure_trusted_user!
  
  def create
    @report = @content.reports.build(report_params)
    @report.user = current_user
    
    if @report.save
      redirect_to @content, notice: 'Thank you for your report. We will review it shortly.'
    else
      redirect_to @content, alert: @report.errors.full_messages.first
    end
  end
  
  private
  
  def set_content
    @content = Content.find(params[:content_id])
  end
  
  def ensure_trusted_user!
    unless current_user.trusted?
      redirect_to @content, alert: 'You must be a trusted user to report content.'
    end
  end
  
  def report_params
    params.require(:report).permit(:reason, :description)
  end
end 