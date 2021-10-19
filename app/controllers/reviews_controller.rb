# frozen_string_literal: true

##
# Reviews for rule reviews.
#
class ReviewsController < ApplicationController
  before_action :set_rule
  before_action :authorize_author_project

  def create
    review = Review.new(review_params.merge({ user: current_user, rule: @rule }))
    if review.save
      render json: { toast: 'Successfully added review.' }
    else
      render json: {
        toast: {
          title: 'Could not add review.',
          message: review.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
    end
  end

  private

  def set_rule
    @rule = Rule.find(params[:rule_id])
  end

  def review_params
    params.require(:review).permit(:action, :comment)
  end
end
