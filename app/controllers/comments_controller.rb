# frozen_string_literal: true

##
# Controller for rule comments.
#
class CommentsController < ApplicationController
  before_action :set_rule_and_project
  before_action :authorize_review_project

  def create
    comment = Comment.new(comment_params.merge({ user: current_user, rule: @rule }))
    comment.save
  end

  private

  def set_rule_and_project
    @rule = Rule.find(params[:rule_id])
    @project = @rule.project
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
