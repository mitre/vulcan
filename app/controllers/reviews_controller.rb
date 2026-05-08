# frozen_string_literal: true

##
# Reviews for rule reviews.
#
class ReviewsController < ApplicationController
  before_action :set_rule, only: %i[create]
  before_action :set_component, only: %i[lock_controls lock_sections]
  before_action :set_review, only: %i[triage adjudicate reopen withdraw update admin_withdraw admin_restore admin_destroy move_to_rule section responses]
  # withdraw added so :authorize_viewer_project
  # below has @project to check against. Policy: a user removed from the project
  # has no remaining authority on the project, including the ability to alter
  # their own pending comments. The comment itself stays put (project record
  # stability); the actor just loses the ability to alter it after leaving.
  before_action :set_project_from_review, only: %i[triage adjudicate reopen withdraw update admin_withdraw admin_restore admin_destroy move_to_rule section responses]
  before_action :set_project
  before_action :authorize_viewer_project, only: %i[create withdraw update]
  before_action :authorize_admin_component, only: %i[lock_controls]
  before_action :authorize_review_component, only: %i[lock_sections]
  before_action :authorize_author_project, only: %i[triage adjudicate reopen section]
  before_action :authorize_review_owner, only: %i[withdraw update]
  # admin override actions are gated to project admins.
  # Authorization runs from set_project_from_review, so @project is set.
  before_action :authorize_admin_project, only: %i[admin_withdraw admin_restore admin_destroy move_to_rule]
  # Reply chain visibility mirrors the parent component's read auth:
  # released → any logged-in user; unreleased → project member.
  before_action :authorize_review_visibility, only: %i[responses]
  # gates the public-comment lifecycle.
  # Runs AFTER auth so non-members get the auth error, not a phase error.
  # admin_withdraw + admin_restore are NOT included — admin overrides are
  # the whole point and must work even after the comment window closes
  # (e.g., remove PII discovered post-final).
  before_action :reject_if_comments_closed, only: %i[create]
  before_action :reject_if_frozen_for_writes, only: %i[triage adjudicate reopen withdraw update section]
  # single audit-comment gate. Each
  # mutating endpoint that requires an operator-supplied reason was
  # open-coding the same blank-check + 422 toast (5 sites, ~8 lines each).
  # Filter normalizes once, sets @audit_comment, and renders the
  # action-specific 422 toast on blank.
  AUDIT_COMMENT_LABELS = {
    admin_withdraw: 'admin force-withdraw',
    admin_restore: 'admin restore',
    move_to_rule: 'admin move-to-rule',
    admin_destroy: 'admin hard-delete',
    section: 'section change'
  }.freeze
  # defense-in-depth length cap on the
  # operator-supplied audit_comment. Postgres `text` has no built-in
  # ceiling; admin endpoints accept arbitrary text. 4096 chars is enough
  # for any reasonable explanation while bounding abuse vectors.
  AUDIT_COMMENT_MAX_LENGTH = 4096
  before_action :require_audit_comment,
                only: %i[admin_withdraw admin_restore move_to_rule admin_destroy section]

  # action-keyed title map for the
  # generic ActiveRecord::RecordInvalid handler on ApplicationController.
  # Replaces 10 hand-written `rescue ActiveRecord::RecordInvalid => e`
  # blocks that all rendered the same shape with a per-action title.
  record_invalid_titles(
    triage: 'Could not save triage.',
    adjudicate: 'Could not close.',
    reopen: 'Could not re-open.',
    withdraw: 'Could not withdraw.',
    admin_withdraw: 'Could not force-withdraw.',
    admin_restore: 'Could not restore.',
    move_to_rule: 'Could not move.',
    admin_destroy: 'Could not hard-delete.',
    section: 'Could not save section.',
    update: 'Could not save edit.'
  )

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

      # canonical object-shape toast
      # (was a bare string pre-fix). Frontend AlertMixin now sees a
      # uniform shape across every PR-717 endpoint.
      render_toast(title: 'Comment posted.', message: '', variant: 'success', status: :ok)
    else
      render_toast(title: 'Could not add review.', message: review.errors.full_messages)
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
      return render_toast(title: 'Cannot re-triage.',
                          message: 'This comment is already closed.',
                          variant: 'warning')
    end

    if (validation_error = validate_triage_params)
      return render_toast(title: 'Could not save triage.', message: validation_error)
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
      return render_toast(title: 'Cannot close yet.',
                          message: 'Comment must be triaged before it can be closed.',
                          variant: 'warning')
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
  end

  # PATCH /reviews/:id/reopen — author+ reverts an adjudicated comment back
  # to "decided but not adjudicated" so the triage decision can be revised.
  # Withdrawn comments are commenter-revoked and NOT re-openable by triagers
  # (the commenter would have to post a new comment instead). Idempotent on
  # withdraw-rejection: state is unchanged and 422 is returned.
  def reopen
    if @review.adjudicated_at.blank?
      return render_toast(title: 'Cannot re-open.',
                          message: 'This comment has not been adjudicated.',
                          variant: 'warning')
    end

    if @review.triage_status == 'withdrawn'
      return render_toast(title: 'Cannot re-open.',
                          message: 'Withdrawn comments can only be re-opened by the original commenter.',
                          variant: 'warning')
    end

    @review.update!(adjudicated_at: nil, adjudicated_by_id: nil)
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  end

  # PATCH /reviews/:id/withdraw — commenter retracts their own comment
  # before triage. Allowed only when triage_status is 'pending' or
  # 'needs_clarification'. The Review#auto_set_adjudicated_for_terminal_statuses
  # callback (Task 06) fills in adjudicated_at + adjudicated_by_id=self.
  def withdraw
    unless %w[pending needs_clarification].include?(@review.triage_status)
      return render_toast(title: 'Cannot withdraw.',
                          message: I18n.t('vulcan.triage.errors.cannot_withdraw_already_triaged'),
                          variant: 'warning')
    end

    @review.update!(triage_status: 'withdrawn')
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  end

  # PATCH /reviews/:id/admin_withdraw.
  # Project admin overrides commenter intent (spam, PII leak, content
  # violating policy, withdrawn-account cleanup). Sets withdrawn +
  # adjudicated attribution to the admin (overriding the auto-set
  # callback's default of self-adjudication for terminal statuses).
  # Audit comment is required — captures the documented reason on the
  # vulcan_audited trail for audit review.
  # Allowed even on already-adjudicated comments and even when the
  # component is frozen_for_writes (admin override is the whole point).
  def admin_withdraw
    @review.audit_comment = "Admin force-withdraw: #{@audit_comment}"
    @review.update!(
      triage_status: 'withdrawn',
      adjudicated_at: Time.current,
      adjudicated_by_id: current_user.id
    )
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  end

  # PATCH /reviews/:id/admin_restore.
  # Inverse of admin_withdraw (and any other adjudication): reverts to
  # 'pending' so the comment can be re-triaged through the normal flow.
  # Required when admin force-withdrew the wrong comment, or when a
  # prior triage decision needs to be reopened beyond what the standard
  # reopen action allows (which leaves triage_status intact).
  # Rejects when the comment is not adjudicated — there's nothing to
  # restore from.
  def admin_restore
    if @review.adjudicated_at.blank?
      return render_toast(title: 'Cannot restore.',
                          message: 'This comment has not been adjudicated.',
                          variant: 'warning')
    end

    @review.audit_comment = "Admin restore: #{@audit_comment}"
    @review.update!(
      triage_status: 'pending',
      adjudicated_at: nil,
      adjudicated_by_id: nil
    )
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  end

  # PATCH /reviews/:id/move_to_rule.
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
    target_rule_id = params[:rule_id].to_i
    if target_rule_id == @review.rule_id
      return render_toast(title: 'Cannot move.',
                          message: 'Target rule is the same as the source rule.',
                          variant: 'warning')
    end

    target_rule = Rule.find_by(id: target_rule_id)
    return head :not_found unless target_rule

    unless target_rule.component_id == @review.rule.component_id
      return render_toast(title: 'Cannot move.',
                          message: 'Target rule must be in the same component.',
                          variant: 'warning')
    end

    Review.transaction do
      # same lock! pattern as
      # admin_destroy. SELECT FOR UPDATE inside the txn so a concurrent
      # move_to_rule or admin_destroy on the same subtree waits for
      # ours to commit. lock! must be inside a txn — held only for the
      # executing statement otherwise.
      @review.lock!

      # write an outbound audit on the
      # SOURCE rule before the move. vulcan_audited associated_with: :rule
      # attaches per-review audit rows to the NEW rule (after update),
      # leaving the source rule's audit feed silent about the departure.
      # This row closes that forensic asymmetry: reviewers auditing the
      # source rule's history see "review X moved out to rule Y" with
      # full context.
      source_rule = @review.rule
      source_rule.audits.create!(
        user: current_user,
        action: 'review_moved_out',
        comment: "Admin move-to-rule: review #{@review.id} → rule #{target_rule.id}: #{@audit_comment}",
        audited_changes: {
          review_id: @review.id,
          source_rule_id: source_rule.id,
          destination_rule_id: target_rule.id,
          reply_count: @review.responses.count
        }
      )

      move_review_subtree!(@review, target_rule.id, @audit_comment)
    end
    render json: { review: ReviewBlueprint.render_as_hash(@review.reload) }
  end

  # DELETE /reviews/:id/admin_destroy.
  # Irreversible: hard-delete a comment (PII / sensitive content / legal
  # request) and its reply subtree (Review#responses dependent: :destroy
  # cascade). Audit entry is created on the COMPONENT BEFORE the destroy
  # so the trail survives — the destroyed review's own audit records
  # remain on the audited gem's table but the auditable record is gone.
  def admin_destroy
    # capture id BEFORE the destroy
    # so the canonical response shape (`{review: nil, destroyed_id:}`)
    # has the value even after the row is gone.
    destroyed_id = @review.id

    Review.transaction do
      # row lock against concurrent
      # admin race (move_to_rule by one admin + hard-delete by another).
      # SELECT FOR UPDATE inside the transaction so the lock is held
      # until commit/rollback. lock! must be called within a txn — held
      # only for the executing statement otherwise.
      @review.lock!

      component = @review.rule.component
      component_audit_payload = {
        review_id: @review.id,
        rule_id: @review.rule_id,
        author_id: @review.user_id,
        reply_count: @review.responses.count,
        # full pre-destroy snapshot of
        # the entire reply subtree (parent + every descendant). For PII /
        # legal hard-delete, the snapshot IS the legal record. Captured
        # via WITH RECURSIVE CTE; timestamps are ISO8601 strings so YAML
        # safe-load doesn't break on Audit#find.
        destroyed_review_snapshots: Review.subtree_with_ancestry(@review.id).map(&:snapshot_attributes)
      }

      # Audit BEFORE destroy so the trail survives the cascade.
      component.audits.create!(
        user: current_user,
        action: 'admin_destroy_review',
        comment: "Admin hard-delete review #{@review.id}: #{@audit_comment}",
        audited_changes: component_audit_payload
      )
      @review.destroy!
    end
    # canonical response shape:
    # `review: nil` mirrors every other admin/triage endpoint that
    # returns `{review: <hash>}`; destroyed_id carries the destroyed
    # row id for any future client logic that wants to reconcile state
    # without keeping the original review prop in scope.
    render json: { review: nil, destroyed_id: destroyed_id }
  end

  # PATCH /reviews/:id/section.
  # Triager (author+) retags an existing comment's `section` so misclassified
  # comments land in the correct per-section thread without rejecting the
  # commenter or going out-of-band via the console. Audit-comment required.
  # Idempotent: re-posting the same section returns 200 with no audit record.
  # Section value validates against Review::SECTION_KEYS (canonical XCCDF
  # keys) plus nil for "(general)". Subject to reject_if_frozen_for_writes
  # like triage/adjudicate — phase=final blocks edits.
  def section
    new_section = params.key?(:section) ? params[:section].presence : @review.section
    unless new_section.nil? || Review::SECTION_KEYS.include?(new_section)
      return render_toast(title: 'Invalid section.',
                          message: "#{new_section.inspect} is not a recognized section key.")
    end

    # Idempotent short-circuit: re-saving the same section is a no-op. Surface
    # an explicit `idempotent: true` flag so spec coverage can verify the
    # controller actively detected the no-change path (otherwise the test
    # would be tautological — Rails update!(same_value) writes no audit
    # regardless of whether the short-circuit is in place).
    if new_section == @review.section # rubocop:disable Style/IfUnlessModifier -- modifier form > 120 chars
      return render json: { review: ReviewBlueprint.render_as_hash(@review), idempotent: true }
    end

    @review.audit_comment = "Section change: #{@audit_comment}"
    @review.update!(section: new_section)
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  end

  # PUT /reviews/:id — commenter edits their own comment text. Allowed
  # only while triage_status='pending'. Audited gem (Task 06) captures
  # the prior text on the audit trail. Strong params lock to :comment
  # only — lifecycle fields stay server-controlled.
  def update
    unless @review.triage_status == 'pending'
      return render_toast(title: 'Cannot edit.',
                          message: I18n.t('vulcan.triage.errors.cannot_edit_after_triage'),
                          variant: 'warning')
    end

    @review.update!(review_update_params)
    render json: { review: ReviewBlueprint.render_as_hash(@review) }
  end

  # GET /reviews/:id/responses — fetch the reply chain under a top-level
  # comment. Auth mirrors the parent component's read gate (released
  # → any logged-in user; unreleased → project member). Returns replies
  # in chronological (oldest-first) order, matching the order RuleReviews
  # uses for nested replies.
  def responses
    replies = @review.responses
                     .preload(:user)
                     .order(:created_at)
    reaction_counts = Reaction.where(review_id: replies.map(&:id)).group(:review_id, :kind).count
    rows = replies.map do |r|
      {
        id: r.id,
        responding_to_review_id: r.responding_to_review_id,
        section: r.section,
        comment: r.comment,
        created_at: r.created_at,
        commenter_display_name: r.commenter_display_name,
        commenter_imported: r.commenter_imported?,
        reactions: { up: reaction_counts[[r.id, 'up']] || 0,
                     down: reaction_counts[[r.id, 'down']] || 0 }
      }
    end
    inject_reactions_mine!(rows)
    response.headers['Cache-Control'] = 'no-store'
    render json: { rows: rows }
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
      render_toast(title: 'No controls could be locked.',
                   message: warnings.join("\n"),
                   variant: 'warning')
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
      render_toast(title: 'Could not lock controls.', message: save_failure_messages)
      return
    end

    title = "Locked #{locked_names.size} #{'control'.pluralize(locked_names.size)}."
    message = "Locked: #{locked_names.join(', ')}"
    message += "\n\n#{warnings.join("\n")}" if warnings.any?

    render_toast(title: title,
                 message: message,
                 variant: warnings.any? ? 'warning' : 'success',
                 status: :ok)
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
      return render_toast(title: 'Could not apply section lock.',
                          message: 'A database error prevented the section lock from being applied. No rules were modified.')
    end

    action_word = locked ? 'locked' : 'unlocked'
    render_toast(title: 'Section lock applied',
                 message: "#{action_word.capitalize} #{sections.size} section(s) on #{count} rule(s)",
                 variant: 'success',
                 status: :ok)
  end

  private

  # single before_action gate for
  # the audit_comment param. Sets @audit_comment for the action body;
  # renders an action-specific 422 toast on blank or oversized.
  def require_audit_comment
    @audit_comment = params[:audit_comment].to_s.strip
    label = AUDIT_COMMENT_LABELS.fetch(action_name.to_sym, 'this action')

    if @audit_comment.blank?
      return render_toast(title: 'Audit comment required.',
                          message: "An audit comment is required for #{label}.")
    end

    return unless @audit_comment.length > AUDIT_COMMENT_MAX_LENGTH

    render_toast(title: 'Audit comment too long.',
                 message: "Audit comment for #{label} must be #{AUDIT_COMMENT_MAX_LENGTH} characters or fewer " \
                          "(received #{@audit_comment.length}).")
  end

  # recursive parent-first walk for move_to_rule.
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

  # Visibility filter for the reply-chain read endpoint. Mirrors
  # ComponentsController#authorize_component_access (released → any
  # logged-in user; unreleased → project member) so reply visibility
  # tracks parent-comment visibility exactly. Sets @component for the
  # authorize_viewer_component delegate.
  def authorize_review_visibility
    @component = @review&.rule&.component
    return head :not_found unless @component

    if @component.released
      authorize_logged_in
    else
      authorize_viewer_component
    end
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

  # a public comment (action='comment') can only be
  # posted while the component's comment_phase is 'open'. Other actions
  # (request_review, approve, request_changes, lock_control,
  # unlock_control) are role-gated independently and unaffected by this
  # filter — we early-return for them.
  # Replies to existing threads (responding_to_review_id present) are
  # still permitted during the adjudicating phase to support back-and-forth
  # clarification with project managers after the comment window closes.
  def reject_if_comments_closed
    return unless params.dig(:review, :action) == 'comment'

    component = @rule&.component
    return if component&.accepting_new_comments?

    is_reply = params.dig(:review, :responding_to_review_id).present?
    return if is_reply && component&.accepting_replies?

    if is_reply
      render_toast(title: 'Could not add reply.',
                   message: 'Replies are closed for this component.')
    else
      render_toast(title: 'Could not add comment.',
                   message: 'Comments are closed for this component.')
    end
  end

  # once a component's comment_phase reaches 'final',
  # the component is frozen — no new triage decisions, adjudications,
  # withdrawals, or self-edits can be applied to its Reviews. The
  # disposition matrix is published; the trail is immutable.
  def reject_if_frozen_for_writes
    component = @review&.rule&.component
    return unless component&.frozen_for_writes?

    render_toast(title: 'Cannot modify review.',
                 message: 'The component is frozen — its public-comment phase is final.')
  end
end
