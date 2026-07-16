# frozen_string_literal: true

# 👍/👎 reactions on comment-action Reviews. Toggle-on-create-or-destroy
# semantics (one reaction per (user, review)). POST gated to viewer+
# of the parent project AND comment_phase='open'; GET works in any
# phase so historical reactions stay visible during closed periods.
#
# Existence-oracle hardening: set_review conceals missing, non-comment, and
# non-discoverable-project reviews behind the same 404 not_found so a
# non-member can't probe review IDs. (Members of a discoverable project still
# get an honest 403 — they can already see the project exists.)
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
    return deny_existence! unless @review && @review.action == Review::ACTION_COMMENT

    @project = @review.component&.project
  end

  # Conceal as a plain 404 not_found — byte-identical to a true miss and to
  # the concealed denial a non-member gets for a comment in a non-discoverable
  # project. A missing or non-comment review must be indistinguishable from a
  # real comment the caller may not reach, so review ids cannot be probed.
  def deny_existence!
    render_resource_not_found
  end

  def verify_comments_open
    component = @review.component
    return if component&.accepting_new_comments?

    key = "vulcan.reaction.closed_period_message.#{component.closed_reason || 'default'}"
    message = I18n.t(key, default: I18n.t('vulcan.reaction.closed_period_message.default'))
    render_toast(title: 'Could not save reaction.', message: message)
  end
end
