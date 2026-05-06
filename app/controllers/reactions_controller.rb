# frozen_string_literal: true

# 👍/👎 reactions on comment-action Reviews. Toggle-on-create-or-destroy
# semantics (one reaction per (user, review)). POST gated to viewer+
# of the parent project AND comment_phase='open'; GET works in any
# phase so historical reactions stay visible during closed periods.
#
# Existence-oracle hardening: set_review returns the same structured 403
# for missing/non-comment/non-member reviews so a non-member can't probe
# review IDs.
class ReactionsController < ApplicationController
  before_action :set_review
  before_action :authorize_viewer_project
  before_action :verify_comments_open, only: :create

  def index
    grouped = Reaction.where(review_id: @review.id)
                      .includes(:user)
                      .order(:created_at)
                      .group_by(&:kind)
    render json: {
      up: (grouped['up'] || []).map { |r| { name: r.user&.name } },
      down: (grouped['down'] || []).map { |r| { name: r.user&.name } }
    }
  end

  def create
    kind = params[:kind].to_s
    unless Reaction::KINDS.include?(kind)
      return render_toast(title: 'Could not save reaction.',
                          message: 'Invalid reaction kind.')
    end

    toggle_reaction(kind)
    summary = Reaction.summary([@review.id], current_user.id)[@review.id]
    render json: { reactions: summary }
  rescue ActiveRecord::RecordInvalid => e
    render_toast(title: 'Could not save reaction.', message: e.record.errors.full_messages)
  end

  private

  # Lock the (review_id, user_id) row inside the transaction; rescue the
  # RecordNotUnique race where two concurrent transactions both miss the
  # lookup and attempt insert. The summary call after this picks up the
  # winning row.
  def toggle_reaction(kind)
    Reaction.transaction do
      existing = Reaction.lock.find_by(review_id: @review.id, user_id: current_user.id)
      if existing.nil?
        Reaction.create!(review: @review, user: current_user, kind: kind)
      elsif existing.kind == kind
        existing.destroy!
      else
        existing.update!(kind: kind)
      end
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def set_review
    @review = Review.find_by(id: params[:review_id])
    return deny_existence! unless @review && @review.action == 'comment'

    @project = @review.rule&.component&.project
  end

  # Soft 403: same shape as authz denial regardless of whether the
  # review is missing, non-comment, or unreachable. Closes the
  # existence-oracle path; "isn't available" wording avoids misleading
  # users who hit a stale link to a deleted comment.
  def deny_existence!
    render json: {
      error: 'permission_denied',
      message: "The requested comment isn't available.",
      admins: [],
      toast: { title: 'Not available.',
               message: "The requested comment isn't available.",
               variant: 'danger' }
    }, status: :forbidden
  end

  def verify_comments_open
    component = @review.rule.component
    return if component.accepting_new_comments?

    key = "vulcan.reaction.closed_period_message.#{component.closed_reason || 'default'}"
    message = I18n.t(key, default: I18n.t('vulcan.reaction.closed_period_message.default'))
    render_toast(title: 'Could not save reaction.', message: message)
  end
end
