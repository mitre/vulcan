# frozen_string_literal: true

##
# Reviews for rule reviews.
#
class ReviewsController < ApplicationController
  before_action :set_rule_and_project
  before_action :authorize_review_project

  def create
    review = Review.new(review_params.merge({ user: current_user, rule: @rule }))
    ActiveRecord::Base.transaction do
      if review.save
        # this will need to change with PR #229
        render json: { notice: 'Successfully added review.' }
        return
      end
    end

    # this will need to change with PR #229
    render json: { alert: "Could not add review. #{review.errors.full_messages}" }, status: :unprocessable_entity
  end

  private

  def set_rule_and_project
    @rule = Rule.find(params[:rule_id])
    @project = @rule.project
  end

  def review_params
    params.require(:review).permit(:action, :comment)
  end
end
