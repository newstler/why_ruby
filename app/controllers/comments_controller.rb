class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :set_comment, only: [ :destroy ]
  before_action :authorize_user!, only: [ :destroy ]

  def create
    @comment = @post.comments.build(comment_params)
    @comment.user = current_user
    @comment.published = true # Auto-publish for now

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @post, notice: "Comment was successfully posted." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("new_comment_form", partial: "comments/form", locals: { post: @post, comment: @comment }) }
        format.html { redirect_to @post, alert: "Error posting comment." }
      end
    end
  end

  def destroy
    @comment.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("comment-#{@comment.id}") }
      format.html { redirect_to @post, notice: "Comment was deleted." }
    end
  end

  private

  def set_post
    @post = Post.friendly.find(params[:post_id])
  end

  def set_comment
    @comment = @post.comments.find(params[:id])
  end

  def authorize_user!
    unless @comment.user == current_user || current_user.admin?
      redirect_to @post, alert: "Not authorized"
    end
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
