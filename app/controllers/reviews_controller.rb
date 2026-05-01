# frozen_string_literal: true

##
# Reviews for rule reviews.
#
class ReviewsController < ApplicationController
  before_action :set_rule, only: %i[create]
  before_action :set_component, only: %i[lock_controls lock_sections]
  before_action :set_review, only: %i[triage adjudicate reopen withdraw update admin_withdraw admin_restore admin_destroy move_to_rule section]
  # PR-717 review remediation .6 — withdraw added so :authorize_viewer_project
  # below has @project to check against. Policy: a user removed from the project
  # has no remaining authority on the project, including the ability to alter
  # their own pending comments. The comment itself stays put (project record
  # stability); the actor just loses the ability to alter it after leaving.
  before_action :set_project_from_review, only: %i[triage adjudicate reopen withdraw update admin_withdraw admin_restore admin_destroy move_to_rule section]
  before_action :set_project
  before_action :authorize_viewer_project, only: %i[create withdraw update]
  before_action :authorize_admin_component, only: %i[lock_controls]
  before_action :authorize_review_component, only: %i[lock_sections]
  before_action :authorize_author_project, only: %i[triage adjudicate reopen section]
  before_action :authorize_review_owner, only: %i[withdraw update]
  # PR-717 Task 25 — admin override actions are gated to project admins.
  # Authorization runs from set_project_from_review, so @project is set.
  before_action :authorize_admin_project, only: %i[admin_withdraw admin_restore admin_destroy move_to_rule]
  # PR #717 phase enforcement — gates the public-comment lifecycle.
  # Runs AFTER auth so non-members get the auth error, not a phase error.
  # admin_withdraw + admin_restore are NOT included — admin overrides are
  # the whole point and must work even after the comment window closes
  # (e.g., remove PII discovered post-final).
  before_action :reject_if_comments_closed, only: %i[create]
  before_action :reject_if_frozen_for_writes, only: %i[triage adjudicate reopen withdraw update section]

  def create
    review_params_without_component_id = review_params.except('component_id')
    review = Review.new(review_params_without_component_id.merge({ user: current_user, rule: @rule }))

    # Explicit transaction + StatementInvalid rescue. AR's save-internal
    # transaction already rolls back take_review_action's rule.save! when an
    # insert raises, but propagating the raw exception to the client returns
    # a 500. Wrap + rescue pairs data-integrity protection with graceful
    # error rendering so the user gets a danger toast and the audit trail
    # remains in sync.
    saved = false
    begin
      Review.transaction do
        saved = review.save
        raise ActiveRecord::Rollback unless saved
      end
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("Review save failed for rule=#{@rule.id} user=#{current_user.id}: #{e.message}")
      review.errors.add(:base, 'Could not save review due to a database error. Please retry.')
      saved = false
    end

    if saved
      if Settings.smtp.enabled
        safely_notify("review_#{review_params[:action]}_smtp") do
          send_smtp_notification(
            UserMailer,
            review_params[:action],
            current_user,
            review_params[:component_id],
            review_params[:comment],
            @rule
          )
        end
      end

      if Settings.slack.enabled
        safely_notify("review_#{review_params[:action]}_slack") do
          send_slack_notification(
            review_params[:action].to_sym,
            @rule,
            review_params[:comment]
          )
        end
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

  # PATCH /reviews/:id/triage — author+ records a triage decision on a
  # top-level comment Review. If response_comment is supplied, atomically
  # creates a child Review (action='comment', responding_to_review_id) so
  # the response renders inline in the rule's existing thread.
  #
  # Validation per design §3.5:
  #   - triage_status must be one of Review::TRIAGE_STATUSES
  #   - non_concur (Decline) requires response_comment
  #   - duplicate requires duplicate_of_review_id
  # Terminal statuses (duplicate / informational / withdrawn) auto-set
  # adjudicated_at via the Review#auto_set_adjudicated_for_terminal_statuses
  # callback from Task 06.
  def triage
    if @review.adjudicated_at.present? &&
       Review::TERMINAL_AUTO_ADJUDICATE_STATUSES.exclude?(params[:triage_status])
      return render json: {
        toast: { title: 'Cannot re-triage.', message: ['This comment is already closed.'], variant: 'warning' }
      }, status: :unprocessable_entity
    end

    if (validation_error = validate_triage_params)
      return render json: {
        toast: { title: 'Could not save triage.', message: [validation_error], variant: 'danger' }
      }, status: :unprocessable_entity
    end

    response_review = nil
    Review.transaction do
      @review.update!(
        triage_status: params[:triage_status],
        triage_set_by_id: current_user.id,
        triage_set_at: Time.current,
        duplicate_of_review_id: params[:duplicate_of_review_id]
      )

      if params[:response_comment].present?
        response_review = Review.create!(
          action: 'comment',
          comment: params[:response_comment],
          user: current_user,
          rule: @review.rule,
          responding_to_review_id: @review.id,
          section: @review.section
        )
      end
    end

    render json: {
      review: ReviewBlueprint.render_as_hash(@review),
      response_review: response_review ? ReviewBlueprint.render_as_hash(response_review) : nil
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not save triage.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PATCH /reviews/:id/adjudicate — author+ marks a triaged comment as
  # adjudicated (closed). Idempotent: re-adjudicate is a no-op returning
  # current state. A still-pending comment must be triaged before it can
  # be closed (422).
  #
  # If resolution_comment is supplied, atomically creates a child Review
  # (action='comment', responding_to_review_id, inherited section) so the
  # final resolution renders inline in the rule's existing thread.
  def adjudicate
    if @review.adjudicated_at.present?
      return render json: {
        review: ReviewBlueprint.render_as_hash(@review),
        response_review: nil
      }
    end

    if @review.triage_status == 'pending'
      return render json: {
        toast: { title: 'Cannot close yet.',
                 message: ['Comment must be triaged before it can be closed.'],
                 variant: 'warning' }
      }, status: :unprocessable_entity
    end

    response_review = nil
    Review.transaction do
      @review.update!(adjudicated_at: Time.current, adjudicated_by_id: current_user.id)

      if params[:resolution_comment].present?
        response_review = Review.create!(
          action: 'comment',
          comment: params[:resolution_comment],
          user: current_user,
          rule: @review.rule,
          responding_to_review_id: @review.id,
          section: @review.section
        )
      end
    end

    render json: {
      review: ReviewBlueprint.render_as_hash(@review),
      response_review: response_review ? ReviewBlueprint.render_as_hash(response_review) : nil
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not close.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PATCH /reviews/:id/reopen — author+ reverts an adjudicated comment back
  # to "decided but not adjudicated" so the triage decision can be revised.
  # Withdrawn comments are commenter-revoked and NOT re-openable by triagers
  # (the commenter would have to post a new comment instead). Idempotent on
  # withdraw-rejection: state is unchanged and 422 is returned.
  def reopen
    if @review.adjudicated_at.blank?
      return render json: {
        toast: { title: 'Cannot re-open.',
                 message: ['This comment has not been adjudicated.'],
                 variant: 'warning' }
      }, status: :unprocessable_entity
    end

    if @review.triage_status == 'withdrawn'
      return render json: {
        toast: { title: 'Cannot re-open.',
                 message: ['Withdrawn comments can only be re-opened by the original commenter.'],
                 variant: 'warning' }
      }, status: :unprocessable_entity
    end

    @review.update!(adjudicated_at: nil, adjudicated_by_id: nil)
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not re-open.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PATCH /reviews/:id/withdraw — commenter retracts their own comment
  # before triage. Allowed only when triage_status is 'pending' or
  # 'needs_clarification'. The Review#auto_set_adjudicated_for_terminal_statuses
  # callback (Task 06) fills in adjudicated_at + adjudicated_by_id=self.
  def withdraw
    unless %w[pending needs_clarification].include?(@review.triage_status)
      return render json: {
        toast: { title: 'Cannot withdraw.',
                 message: [I18n.t('vulcan.triage.errors.cannot_withdraw_already_triaged')],
                 variant: 'warning' }
      }, status: :unprocessable_entity
    end

    @review.update!(triage_status: 'withdrawn')
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not withdraw.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PR-717 Task 25 — PATCH /reviews/:id/admin_withdraw.
  # Project admin overrides commenter intent (spam, PII leak, content
  # violating policy, withdrawn-account cleanup). Sets withdrawn +
  # adjudicated attribution to the admin (overriding the auto-set
  # callback's default of self-adjudication for terminal statuses).
  # Audit comment is required — captures the documented reason on the
  # vulcan_audited trail for audit review.
  # Allowed even on already-adjudicated comments and even when the
  # component is frozen_for_writes (admin override is the whole point).
  def admin_withdraw
    audit_comment = params[:audit_comment].to_s.strip
    if audit_comment.blank?
      return render json: {
        toast: { title: 'Audit comment required.',
                 message: ['An audit comment is required for admin force-withdraw.'],
                 variant: 'danger' }
      }, status: :unprocessable_entity
    end

    @review.audit_comment = "Admin force-withdraw: #{audit_comment}"
    @review.update!(
      triage_status: 'withdrawn',
      adjudicated_at: Time.current,
      adjudicated_by_id: current_user.id
    )
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not force-withdraw.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PR-717 Task 25 — PATCH /reviews/:id/admin_restore.
  # Inverse of admin_withdraw (and any other adjudication): reverts to
  # 'pending' so the comment can be re-triaged through the normal flow.
  # Required when admin force-withdrew the wrong comment, or when a
  # prior triage decision needs to be reopened beyond what the standard
  # reopen action allows (which leaves triage_status intact).
  # Rejects when the comment is not adjudicated — there's nothing to
  # restore from.
  def admin_restore
    audit_comment = params[:audit_comment].to_s.strip
    if audit_comment.blank?
      return render json: {
        toast: { title: 'Audit comment required.',
                 message: ['An audit comment is required for admin restore.'],
                 variant: 'danger' }
      }, status: :unprocessable_entity
    end

    if @review.adjudicated_at.blank?
      return render json: {
        toast: { title: 'Cannot restore.',
                 message: ['This comment has not been adjudicated.'],
                 variant: 'warning' }
      }, status: :unprocessable_entity
    end

    @review.audit_comment = "Admin restore: #{audit_comment}"
    @review.update!(
      triage_status: 'pending',
      adjudicated_at: nil,
      adjudicated_by_id: nil
    )
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not restore.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PR-717 Task 26 — PATCH /reviews/:id/move_to_rule.
  # Project admin reassigns a misplaced comment (and atomically all its
  # replies) to a different rule in the same component. Audit comment
  # required; the column-change diff is captured because :rule_id is in
  # the vulcan_audited only: list (review.rb:38).
  #
  # Walks PARENT-FIRST so each child's responding_to_must_be_same_rule
  # validator (review.rb) sees the parent already at the target rule
  # when the child moves. Children-first would fail because the child's
  # parent.rule_id (read fresh from DB by the validator) would still
  # point at the source rule. Wrapped in a transaction so any failure
  # rolls back the entire subtree move.
  def move_to_rule
    audit_comment = params[:audit_comment].to_s.strip
    if audit_comment.blank?
      return render json: {
        toast: { title: 'Audit comment required.',
                 message: ['An audit comment is required for admin move-to-rule.'],
                 variant: 'danger' }
      }, status: :unprocessable_entity
    end

    target_rule_id = params[:rule_id].to_i
    if target_rule_id == @review.rule_id
      return render json: {
        toast: { title: 'Cannot move.',
                 message: ['Target rule is the same as the source rule.'],
                 variant: 'warning' }
      }, status: :unprocessable_entity
    end

    target_rule = Rule.find_by(id: target_rule_id)
    return head :not_found unless target_rule

    unless target_rule.component_id == @review.rule.component_id
      return render json: {
        toast: { title: 'Cannot move.',
                 message: ['Target rule must be in the same component.'],
                 variant: 'warning' }
      }, status: :unprocessable_entity
    end

    Review.transaction do
      move_review_subtree!(@review, target_rule.id, audit_comment)
    end
    render json: { review: ReviewBlueprint.render_as_hash(@review.reload) }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not move.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PR-717 Task 25b — DELETE /reviews/:id/admin_destroy.
  # Irreversible: hard-delete a comment (PII / sensitive content / legal
  # request) and its reply subtree (Review#responses dependent: :destroy
  # cascade). Audit entry is created on the COMPONENT BEFORE the destroy
  # so the trail survives — the destroyed review's own audit records
  # remain on the audited gem's table but the auditable record is gone.
  def admin_destroy
    audit_comment = params[:audit_comment].to_s.strip
    if audit_comment.blank?
      return render json: {
        toast: { title: 'Audit comment required.',
                 message: ['An audit comment is required for admin hard-delete.'],
                 variant: 'danger' }
      }, status: :unprocessable_entity
    end

    component = @review.rule.component
    component_audit_payload = {
      review_id: @review.id,
      rule_id: @review.rule_id,
      author_id: @review.user_id,
      reply_count: @review.responses.count
    }

    Review.transaction do
      # Audit BEFORE destroy so the trail survives the cascade.
      component.audits.create!(
        user: current_user,
        action: 'admin_destroy_review',
        comment: "Admin hard-delete review #{@review.id}: #{audit_comment}",
        audited_changes: component_audit_payload
      )
      @review.destroy!
    end
    render json: { ok: true }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not hard-delete.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PR-717 Task 30 — PATCH /reviews/:id/section.
  # Triager (author+) retags an existing comment's `section` so misclassified
  # comments land in the correct per-section thread without rejecting the
  # commenter or going out-of-band via the console. Audit-comment required.
  # Idempotent: re-posting the same section returns 200 with no audit record.
  # Section value validates against Review::SECTION_KEYS (canonical XCCDF
  # keys) plus nil for "(general)". Subject to reject_if_frozen_for_writes
  # like triage/adjudicate — phase=final blocks edits.
  def section
    audit_comment = params[:audit_comment].to_s.strip
    if audit_comment.blank?
      return render json: {
        toast: { title: 'Audit comment required.',
                 message: ['An audit comment is required for section change.'],
                 variant: 'danger' }
      }, status: :unprocessable_entity
    end

    new_section = params.key?(:section) ? params[:section].presence : @review.section
    unless new_section.nil? || Review::SECTION_KEYS.include?(new_section)
      return render json: {
        toast: { title: 'Invalid section.',
                 message: ["#{new_section.inspect} is not a recognized section key."],
                 variant: 'danger' }
      }, status: :unprocessable_entity
    end

    # Idempotent short-circuit: re-saving the same section is a no-op. Surface
    # an explicit `idempotent: true` flag so spec coverage can verify the
    # controller actively detected the no-change path (otherwise the test
    # would be tautological — Rails update!(same_value) writes no audit
    # regardless of whether the short-circuit is in place).
    if new_section == @review.section # rubocop:disable Style/IfUnlessModifier -- modifier form > 120 chars
      return render json: { review: ReviewBlueprint.render_as_hash(@review), idempotent: true }
    end

    @review.audit_comment = "Section change: #{audit_comment}"
    @review.update!(section: new_section)
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not save section.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
  end

  # PUT /reviews/:id — commenter edits their own comment text. Allowed
  # only while triage_status='pending'. Audited gem (Task 06) captures
  # the prior text on the audit trail. Strong params lock to :comment
  # only — lifecycle fields stay server-controlled.
  def update
    unless @review.triage_status == 'pending'
      return render json: {
        toast: { title: 'Cannot edit.',
                 message: [I18n.t('vulcan.triage.errors.cannot_edit_after_triage')],
                 variant: 'warning' }
      }, status: :unprocessable_entity
    end

    @review.update!(review_update_params)
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      toast: { title: 'Could not save edit.', message: e.record.errors.full_messages, variant: 'danger' }
    }, status: :unprocessable_entity
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
    save_failure_messages = nil
    Review.transaction do
      lockable.each do |rule|
        review = Review.new(review_params.merge({ user: current_user, rule: rule }))
        next if review.save

        save_failure_messages = review.errors.full_messages
        raise ActiveRecord::Rollback
      end
      locked_names = lockable.map(&:displayed_name)
    end

    if save_failure_messages
      render json: {
        toast: {
          title: 'Could not lock controls.',
          message: save_failure_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
      return
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

    # Wrap the per-rule updates in a single transaction so a failure on
    # rule N+1 rolls back rules 1..N. Without this, the loop committed
    # each rule independently and a mid-loop failure left the component
    # in a partial-write state plus surfaced a 500 to the user.
    begin
      Rule.transaction do
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
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      Rails.logger.error("Section lock failed for component=#{@component.id}: #{e.message}")
      return render json: {
        toast: {
          title: 'Could not apply section lock.',
          message: 'A database error prevented the section lock from being applied. No rules were modified.',
          variant: 'danger'
        }
      }, status: :unprocessable_entity
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

  # PR-717 Task 26 — recursive parent-first walk for move_to_rule.
  # Updates the review's rule_id with the audit comment captured by the
  # vulcan_audited gem, then recurses into each child (replies pointing
  # at this review). Children see the parent already at the target rule
  # by the time the validator (responding_to_must_be_same_rule) runs.
  def move_review_subtree!(review, new_rule_id, audit_comment)
    review.audit_comment = "Admin move-to-rule (rule #{new_rule_id}): #{audit_comment}"
    review.update!(rule_id: new_rule_id)
    review.responses.find_each do |child|
      move_review_subtree!(child, new_rule_id, audit_comment)
    end
  end

  def set_rule
    @rule = Rule.find(params[:rule_id])
  end

  def set_component
    @component = Component.find(params[:component_id])
  end

  # Lifecycle endpoints (triage / adjudicate / withdraw / update) operate on
  # a Review by id. Look it up here so the action body never has to.
  def set_review
    @review = Review.find_by(id: params[:id])
    head :not_found unless @review
  end

  # Derives @project from @review's rule chain so the standard
  # authorize_*_project filters work without modification. This is the
  # IDOR guard for cross-project Review access — pairing set_review with
  # this filter forces a project membership check before any state change.
  def set_project_from_review
    return unless @review

    component = @review.rule&.component
    @project = component&.project
  end

  # rubocop:disable Naming/MemoizedInstanceVariableName -- this is a filter,
  # not a memoizer; the `||=` lets set_project_from_review's earlier @project
  # assignment win without overwriting it.
  def set_project
    @project ||= @rule&.component&.project || @component&.project
  end
  # rubocop:enable Naming/MemoizedInstanceVariableName

  # Ownership filter for the commenter-self-service endpoints (withdraw +
  # update). The standard authorize_*_project filters check membership on
  # the project, which a commenter satisfies; this filter additionally
  # requires the current user to be the comment's author.
  def authorize_review_owner
    return if @review && @review.user_id == current_user&.id

    raise NotAuthorizedError, 'You can only modify your own comments.'
  end

  def review_update_params
    params.expect(review: %i[comment])
  end

  def validate_triage_params
    status = params[:triage_status]
    return I18n.t('vulcan.triage.errors.cannot_edit_after_triage') unless Review::TRIAGE_STATUSES.include?(status)
    # 'pending' is the INITIAL state; submitting it as a triage decision
    # would silently re-stamp triage_set_by_id / triage_set_at on a still-
    # untriaged comment. Reject — there's no decision being made.
    return 'Triage decision cannot be "pending" — pick a real status.' if status == 'pending'
    return I18n.t('vulcan.triage.errors.decline_requires_response') if status == 'non_concur' && params[:response_comment].blank?
    return I18n.t('vulcan.triage.errors.duplicate_requires_target') if status == 'duplicate' && params[:duplicate_of_review_id].blank?

    nil
  end

  def review_params
    # Lifecycle fields (triage_status, triage_set_by_id, adjudicated_at,
    # adjudicated_by_id, duplicate_of_review_id) are NEVER user-controllable
    # here — they are set only by the dedicated triage / adjudicate / withdraw
    # endpoints (Tasks 10/11/12).
    params.expect(review: %i[component_id action comment section responding_to_review_id])
  end

  # PR #717 phase gate: a public comment (action='comment') can only be
  # posted while the component's comment_phase is 'open'. Other actions
  # (request_review, approve, request_changes, lock_control,
  # unlock_control) are role-gated independently and unaffected by this
  # filter — we early-return for them.
  def reject_if_comments_closed
    return unless params.dig(:review, :action) == 'comment'
    return if @rule&.component&.accepting_new_comments?

    render json: {
      toast: {
        title: 'Could not add comment.',
        message: 'Comments are closed for this component.',
        variant: 'danger'
      }
    }, status: :unprocessable_entity
  end

  # PR #717 phase gate: once a component's comment_phase reaches 'final',
  # the component is frozen — no new triage decisions, adjudications,
  # withdrawals, or self-edits can be applied to its Reviews. The
  # disposition matrix is published; the trail is immutable.
  def reject_if_frozen_for_writes
    component = @review&.rule&.component
    return unless component&.frozen_for_writes?

    render json: {
      toast: {
        title: 'Cannot modify review.',
        message: 'The component is frozen — its public-comment phase is final.',
        variant: 'danger'
      }
    }, status: :unprocessable_entity
  end
end
