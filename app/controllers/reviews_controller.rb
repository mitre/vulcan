# frozen_string_literal: true

##
# Reviews for rule reviews.
#
class ReviewsController < ApplicationController
  before_action :set_rule, only: %i[create]
  before_action :set_component, only: %i[lock_controls lock_sections]
  before_action :set_project
  before_action :authorize_viewer_project, only: %i[create]
  before_action :authorize_admin_component, only: %i[lock_controls]
  before_action :authorize_review_component, only: %i[lock_sections]

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

      if Settings.slack.enabled
        send_slack_notification(
          review_params[:action].to_sym,
          @rule,
          review_params[:comment]
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

    # Identify rules that can't be locked due to incomplete data (B10: warn but proceed)
    skipped_ids = Set.new
    warnings = []

    # NYD rules without satisfactions
    nyd_rules = unlocked.where(status: 'Not Yet Determined')
    satisfied_ids = RuleSatisfaction.where(rule_id: nyd_rules).pluck(:rule_id)
    nyd_skipped = nyd_rules.where.not(id: satisfied_ids).order(:rule_id)
    if nyd_skipped.any?
      skipped_ids.merge(nyd_skipped.ids)
      names = nyd_skipped.map(&:displayed_name).join(', ')
      warnings << "Not Yet Determined (skipped): #{names}"
    end

    # ADNM without mitigations
    adnm_skipped = unlocked.includes(:disa_rule_descriptions)
                           .where(status: 'Applicable - Does Not Meet',
                                  disa_rule_descriptions: { mitigations: [nil, ''] })
                           .distinct.order(:rule_id)
    if adnm_skipped.any?
      skipped_ids.merge(adnm_skipped.ids)
      names = adnm_skipped.map(&:displayed_name).join(', ')
      warnings << "Does Not Meet without mitigations (skipped): #{names}"
    end

    # AIM without artifact description
    aim_skipped = unlocked.where(status: 'Applicable - Inherently Meets',
                                 artifact_description: [nil, '']).order(:rule_id)
    if aim_skipped.any?
      skipped_ids.merge(aim_skipped.ids)
      names = aim_skipped.map(&:displayed_name).join(', ')
      warnings << "Inherently Meets without artifact (skipped): #{names}"
    end

    # Lock only the valid rules
    lockable = unlocked.where.not(id: skipped_ids.to_a)

    if lockable.empty? && skipped_ids.any?
      render json: {
        toast: {
          title: 'No controls could be locked.',
          message: warnings.join("\n"),
          variant: 'warning'
        }
      }, status: :unprocessable_entity
      return
    end

    locked_names = []
    Review.transaction do
      lockable.each do |rule|
        review = Review.new(review_params.merge({ user: current_user, rule: rule }))
        next if review.save

        render json: {
          toast: {
            title: 'Could not lock controls.',
            message: review.errors.full_messages,
            variant: 'danger'
          }
        }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
      locked_names = lockable.map(&:displayed_name)
    end

    title = "Locked #{locked_names.size} #{'control'.pluralize(locked_names.size)}."
    message = "Locked: #{locked_names.join(', ')}"
    message += "\n\n#{warnings.join("\n")}" if warnings.any?

    render json: {
      toast: {
        title: title,
        message: message,
        variant: warnings.any? ? 'warning' : 'success'
      }
    }
  end

  def lock_sections
    sections = Array(params[:sections])
    locked = ActiveModel::Type::Boolean.new.cast(params[:locked])
    comment = params[:comment]

    invalid = sections - RuleConstants::LOCKABLE_SECTION_NAMES
    return render json: { error: "Invalid sections: #{invalid.join(', ')}" }, status: :unprocessable_entity if invalid.any?

    rules = @component.rules.where(locked: false)
    count = 0

    rules.each do |rule|
      old_fields = rule.locked_fields.dup
      fields = rule.locked_fields.dup
      sections.each do |section|
        if locked
          fields[section] = true
        else
          fields.delete(section)
        end
      end
      next if fields == old_fields

      action_word = locked ? 'Locked' : 'Unlocked'
      rule.audit_comment = comment.presence || "#{action_word} sections: #{sections.join(', ')}"
      rule.update!(locked_fields: fields)
      count += 1
    end

    action_word = locked ? 'locked' : 'unlocked'
    render json: {
      toast: {
        title: 'Section lock applied',
        message: "#{action_word.capitalize} #{sections.size} section(s) on #{count} rule(s)",
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
    params.expect(review: %i[component_id action comment])
  end
end
