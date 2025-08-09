class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :set_comment, only: [:destroy]
  before_action :authorize_user!, only: [:destroy]
  
  def create
    @comment = @post.comments.build(comment_params)
    @comment.user = current_user
    @comment.published = true # Auto-publish for now
    
    if @comment.save
      redirect_to @post, notice: 'Comment was successfully posted.'
    else
      redirect_to @post, alert: 'Error posting comment.'
    end
  end
  
  def destroy
    @comment.destroy!
    redirect_to @post, notice: 'Comment was deleted.'
  end
  
  private
  
  def set_post
    @post = Post.find(params[:post_id])
  end
  
  def set_comment
    @comment = @post.comments.find(params[:id])
  end
  
  def authorize_user!
    unless @comment.user == current_user || current_user.admin?
      redirect_to @post, alert: 'Not authorized'
    end
  end
  
  def comment_params
    params.require(:comment).permit(:body)
  end
end 