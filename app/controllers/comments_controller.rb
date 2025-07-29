class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_content
  before_action :set_comment, only: [:destroy]
  before_action :authorize_user!, only: [:destroy]
  
  def create
    @comment = @content.comments.build(comment_params)
    @comment.user = current_user
    @comment.published = true # Auto-publish for now
    
    if @comment.save
      redirect_to @content, notice: 'Comment was successfully posted.'
    else
      redirect_to @content, alert: 'Error posting comment.'
    end
  end
  
  def destroy
    @comment.update!(archived: true)
    redirect_to @content, notice: 'Comment was deleted.'
  end
  
  private
  
  def set_content
    @content = Content.find(params[:content_id])
  end
  
  def set_comment
    @comment = @content.comments.find(params[:id])
  end
  
  def authorize_user!
    unless @comment.user == current_user || current_user.admin?
      redirect_to @content, alert: 'Not authorized'
    end
  end
  
  def comment_params
    params.require(:comment).permit(:body)
  end
end 