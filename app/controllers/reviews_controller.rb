# frozen_string_literal: true

##
# Reviews for rule reviews.
#
class ReviewsController < ApplicationController
  before_action :set_rule, only: %i[create]
  before_action :set_component, only: %i[lock_controls]
  before_action :set_project
  before_action :authorize_author_project, only %i[create]
  before_action :authorize_admin_project, only %i[lock_controls]

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

  def lock_controls
    unlocked = @component.rules.where(locked: false)

    if unlocked.exists?(status: 'Not Yet Determined')
      not_determined_controls = unlocked.where(status: 'Not Yet Determined').map(&:displayed_name).join(', ')
      render json: {
        toast: {
          title: 'Could not lock controls.',
          message: "The following controls are 'Not Yet Determined': #{not_determined_controls}",
          variant: 'danger'
        }
      }, status: :unprocessable_entity
      return
    end

    Review.transaction do
      unlocked.each do |rule|
        review = Review.new(review_params.merge({ user: current_user, rule: rule }))
        next if review.save

        render json: {
          toast: {
            title: 'Could not lock controls.',
            message: review.errors.full_messages,
            variant: 'danger'
          }
        }, status: :unprocessable_entity
      end
    end

    render json: {
      toast: {
        title: "Successfully locked #{unlocked.size} #{'control'.pluralize(unlocked.size)}.",
        message: "The following controls were locked: #{unlocked.map(&:displayed_name).join(', ')}",
        variant: 'success'
      }
    }
  end

  private

  def set_rule
    @rule = Rule.find(params[:rule_id])
  end

  def set_component
    @component = Component.find(params[:component_id])
  end

  def set_project
    @project = @rule&.component&.project || @component&.project
  end

  def review_params
    params.require(:review).permit(:action, :comment)
  end
end
