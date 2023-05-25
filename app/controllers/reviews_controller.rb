# frozen_string_literal: true

##
# Reviews for rule reviews.
#
class ReviewsController < ApplicationController
  before_action :set_rule, only: %i[create]
  before_action :set_component, only: %i[lock_controls]
  before_action :set_project
  before_action :authorize_author_project

  def create
    review_params_without_component_id = review_params.except('component_id')
    review = Review.new(review_params_without_component_id.merge({ user: current_user, rule: @rule }))
    if review.save
      if Settings.smtp.enabled
        send_smtp_notification(
          UserMailer,
          review_params[:action],
          current_user,
          review_params[:component_id],
          review_params[:comment],
          @rule
        )
      end
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
    filtered_unlocked = unlocked.where(status: 'Not Yet Determined')
    satisfied_rule_ids = RuleSatisfaction.where(rule_id: filtered_unlocked).pluck(:rule_id)
    filtered_unlocked = filtered_unlocked.where.not(id: satisfied_rule_ids).order(:rule_id)

    if filtered_unlocked.any?
      not_determined_controls = filtered_unlocked.map { |r| "#{@component[:prefix]}-#{r['rule_id']}" }.join(', ')
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
    params.require(:review).permit(:component_id, :action, :comment)
  end
end

