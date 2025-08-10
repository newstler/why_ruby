class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :ensure_trusted_user!

  def create
    @report = @post.reports.build(report_params)
    @report.user = current_user

    if @report.save
      redirect_to @post, notice: "Thank you for your report. We will review it shortly."
    else
      redirect_to @post, alert: @report.errors.full_messages.first
    end
  end

  private

  def set_post
    @post = Post.friendly.find(params[:post_id])
  end

  def ensure_trusted_user!
    unless current_user.trusted?
      redirect_to @post, alert: "You must be a trusted user to report posts."
    end
  end

  def report_params
    params.require(:report).permit(:reason, :description)
  end
end
