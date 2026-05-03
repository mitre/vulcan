# frozen_string_literal: true

# Reviews on a specific Rule
class Review < ApplicationRecord
  include VulcanAuditable
  include ImportedAttribution

  # PR-717 review remediation .8 + .j4a B1 — see app/models/concerns/
  # imported_attribution.rb for the macro implementation. The three
  # declarations below replace six hand-written method bodies.
  imported_attribution :triager,     via: :triage_set_by
  imported_attribution :adjudicator, via: :adjudicated_by
  imported_attribution :commenter,   via: :user, column_prefix: :commenter

  # PR-717 review remediation .j4a step A2 — optional so reviews.user_id
  # can be NULL after step A3's FK on_delete: :nullify removes the User.
  # Original commenter attribution lives on commenter_imported_email/name
  # columns; #commenter_display_name (step B1) provides the display fallback.
  belongs_to :user, optional: true
  belongs_to :rule
  has_one :component, through: :rule

  belongs_to :triage_set_by, class_name: 'User', optional: true
  belongs_to :adjudicated_by, class_name: 'User', optional: true
  belongs_to :duplicate_of, class_name: 'Review', foreign_key: 'duplicate_of_review_id',
                            optional: true, inverse_of: :duplicates
  has_many :duplicates, class_name: 'Review', foreign_key: 'duplicate_of_review_id',
                        dependent: :nullify, inverse_of: :duplicate_of
  belongs_to :responding_to, class_name: 'Review', foreign_key: 'responding_to_review_id',
                             optional: true, inverse_of: :responses
  has_many :responses, class_name: 'Review', foreign_key: 'responding_to_review_id',
                       dependent: :destroy, inverse_of: :responding_to

  TRIAGE_STATUSES = %w[
    pending concur concur_with_comment non_concur
    duplicate informational needs_clarification withdrawn
  ].freeze

  TERMINAL_AUTO_ADJUDICATE_STATUSES = %w[duplicate informational withdrawn].freeze

  SECTION_KEYS = %w[
    title severity status fixtext check_content vuln_discussion
    disa_metadata vendor_comments artifact_description xccdf_metadata
  ].freeze

  # adjudicated_at is intentionally NOT audited. Auditing a datetime column
  # trips Rails 7.1's safe-YAML dump for ActiveSupport::TimeWithZone. The
  # transition timestamp is recoverable from the audit's created_at on the
  # triage_status record that captured the terminal-state change.
  # Audit-tracked columns. PR-717:
  # - `rule_id` added for Task 26 (admin move-to-rule) so the column-change
  #   diff is captured on the trail, not just the audit_comment text.
  # - `section` added for Task 30 (edit comment section retroactive) so the
  #   triager's section-relocation is auditable.
  # PR-717 review remediation .7 — `associated_with: :rule` so audit rows
  # remain queryable through Rule after admin_destroy cascades a subtree
  # (auditable_id points to a deleted Review; associated_id still points
  # to a valid Rule). Matches the pattern on every other audited model.
  vulcan_audited only: %i[triage_status adjudicated_by_id duplicate_of_review_id comment rule_id section],
                 associated_with: :rule

  scope :top_level_comments, -> { where(action: 'comment', responding_to_review_id: nil) }
  scope :pending_triage, -> { top_level_comments.where(triage_status: 'pending') }
  scope :awaiting_adjudication, lambda {
    top_level_comments.where(triage_status: %w[concur concur_with_comment non_concur])
                      .where(adjudicated_at: nil)
  }

  # PR-717 review remediation .4 step 2 — recursive subtree fetch via
  # Postgres WITH RECURSIVE CTE. Returns root + every descendant via
  # responding_to_review_id chain in one query, ordered so the root
  # appears first and children follow their parent.
  #
  # Used by admin_destroy to capture pre-destroy snapshots of the entire
  # reply tree before Rails dependent: :destroy walks it. Returns an
  # Array<Review> (not Relation — Postgres CTE can't be wrapped in FROM
  # without losing the recursive scope), so callers needing .pluck must
  # post-process via .map.
  def self.subtree_with_ancestry(root_id)
    sql = sanitize_sql_array([<<~SQL.squish, root_id])
      WITH RECURSIVE subtree AS (
        SELECT * FROM reviews WHERE id = ?
        UNION ALL
        SELECT r.* FROM reviews r
        INNER JOIN subtree s ON r.responding_to_review_id = s.id
      )
      SELECT * FROM subtree ORDER BY responding_to_review_id NULLS FIRST, created_at
    SQL
    find_by_sql(sql)
  end

  # Map of role tier → roles that satisfy it (low-to-high inclusive). Replaces
  # the fragile constantize approach so a typo or missing constant raises at
  # boot, not via a 500 at validation time.
  TIER_ROLES = {
    viewers: %w[viewer author reviewer admin],
    authors: %w[author reviewer admin],
    reviewers: %w[reviewer admin],
    admins: %w[admin]
  }.freeze

  # Single source of truth for which action requires which role tier.
  # validate_project_permissions consults this BEFORE the per-action
  # state validators (can_request_review, can_approve, etc.) run — closes
  # the Copilot-flagged bug where a viewer could send action=request_review
  # against an unlocked, not-under-review rule and become the requestor.
  ACTION_PERMISSIONS = {
    'comment' => :viewers,
    'request_review' => :authors,
    'revoke_review_request' => :authors,
    'request_changes' => :reviewers,
    'approve' => :reviewers,
    'lock_control' => :admins,
    'unlock_control' => :admins
  }.freeze

  # Back-compat alias — derived from ACTION_PERMISSIONS so adding a new action
  # is one map entry instead of two.
  VALID_ACTIONS = ACTION_PERMISSIONS.keys.freeze

  validates :comment, :action, presence: true
  # rubocop:disable Rails/I18nLocaleTexts
  validates :action, inclusion: { in: VALID_ACTIONS, message: 'is not a recognized review action' }
  # rubocop:enable Rails/I18nLocaleTexts
  validates :action, length: { maximum: ->(_r) { Settings.input_limits.short_string } }
  # Comment-action reviews are capped at min(Settings.input_limits.review_comment, 4000)
  # to limit abuse surface for external commenters posting via the public-comment path.
  # Other action types use the deployment-configured limit unchanged.
  validates :comment, length: {
    maximum: lambda { |r|
      cap = Settings.input_limits.review_comment
      r.action == 'comment' ? [cap, 4000].min : cap
    }
  }

  # rubocop:disable Rails/I18nLocaleTexts
  # PR-717 review remediation .1 — allow_nil so legacy reviews (rows
  # backfilled to NULL by 20260502120000_make_review_triage_status_nullable)
  # don't trip the validator on subsequent saves. NULL means "not part of
  # a public-comment workflow"; the inclusion list governs every other
  # state transition.
  validates :triage_status, inclusion: { in: TRIAGE_STATUSES }, allow_nil: true
  validates :section, inclusion: { in: SECTION_KEYS, message: 'is not a recognized section' },
                      allow_nil: true
  # rubocop:enable Rails/I18nLocaleTexts
  validate :duplicate_status_requires_target
  # PR-717 review remediation .21 — duplicate_of_review_id only makes
  # sense when triage_status='duplicate'. The existing
  # duplicate_status_requires_target validator catches duplicate-WITHOUT-
  # target; this one catches the opposite (target-without-duplicate-status,
  # e.g. concur + stray duplicate_of_review_id). Without it, a bogus
  # cross-link silently persists and corrupts the disposition matrix
  # "Duplicate Of" column.
  # rubocop:disable Rails/I18nLocaleTexts -- consistent with neighbor validators on this model
  validates :duplicate_of_review_id, absence: { message: 'must be blank when triage_status is not duplicate' },
                                     unless: -> { triage_status == 'duplicate' }
  # rubocop:enable Rails/I18nLocaleTexts
  validate :no_self_responding_reference
  validate :no_self_duplicate_reference
  validate :responding_to_must_be_same_rule
  validate :duplicate_of_must_be_same_component
  validate :duplicate_of_must_not_be_a_duplicate

  before_save :auto_set_adjudicated_for_terminal_statuses

  before_create :take_review_action
  # PR-717 review remediation .1 — the column-level default 'pending' was
  # dropped (legacy rows backfilled to NULL by
  # 20260502120000_make_review_triage_status_nullable). Top-level NEW
  # comments still need to enter the triage queue, so default
  # triage_status to 'pending' here when the row is a new top-level
  # comment AND the caller didn't set it explicitly. Replies
  # (responding_to_review_id present) and non-comment actions
  # (request_review/approve/etc.) stay NULL — they're not triage candidates.
  before_create :default_triage_status_for_new_top_level_comment

  # PR-717 review remediation .9 — user-action validators are explicitly
  # scoped to :create + :update so they run on normal saves but NOT in
  # custom validation contexts. ReviewBuilder calls
  # `review.valid?(:import_integrity)` after Review.insert! to confirm the
  # archive's records satisfy structural invariants (FKs, status enum,
  # cross-rule reply) WITHOUT re-asserting the original user's role tier.
  # Historical archive records aren't user actions; the importing admin
  # operates outside the project tier system.
  # Rails Guides §7.3 (Custom Contexts) is the canonical pattern.
  validate :validate_project_permissions, on: %i[create update]
  validate :can_request_review, on: %i[create update], if: -> { action.eql? 'request_review' }
  validate :can_revoke_review_request,
           on: %i[create update],
           if: -> { action.eql? 'revoke_review_request' }
  validate :can_request_changes, on: %i[create update], if: -> { action.eql? 'request_changes' }
  validate :can_approve, on: %i[create update], if: -> { action.eql? 'approve' }
  validate :can_lock_control, on: %i[create update], if: -> { action.eql? 'lock_control' }
  validate :can_unlock_control, on: %i[create update], if: -> { action.eql? 'unlock_control' }

  delegate :name, to: :user

  ##
  # Serialization is handled by ReviewBlueprint.
  # See app/blueprints/review_blueprint.rb.

  # PR-717 review remediation .8 + .j4a B1 — display-layer attribution
  # for triager / adjudicator / commenter. Resolved User name → the
  # role's imported_name column → imported_email column → nil. When a
  # review is restored from a JSON archive on a different instance the
  # original User may not exist locally; ReviewBuilder preserves the
  # original email + name on `*_imported_*` columns. Display surfaces
  # (CommentTriageModal, ReviewBlueprint, disposition export) call these
  # methods so the fallback is one source of truth.
  #
  # Generated by ImportedAttribution.imported_attribution macro:
  #   triager_display_name / triager_imported?     — via triage_set_by
  #   adjudicator_display_name / adjudicator_imported? — via adjudicated_by
  #   commenter_display_name / commenter_imported? — via user (column_prefix
  #                                                  differs from association
  #                                                  name; declared explicitly)

  # PR-717 review remediation .4 step 4 — pre-destroy snapshot for the
  # admin_destroy Component-level audit row's `audited_changes` payload.
  # Captures the full row state (full comment, every audited + lifecycle
  # column, ISO8601 timestamps so YAML safe-load doesn't break on the
  # audited gem's column deserialization at Audit#find).
  SNAPSHOT_COLUMNS = %w[
    id user_id rule_id action comment section
    triage_status triage_set_by_id triage_set_at
    adjudicated_at adjudicated_by_id
    duplicate_of_review_id responding_to_review_id
    triage_set_by_imported_email triage_set_by_imported_name
    adjudicated_by_imported_email adjudicated_by_imported_name
    commenter_imported_email commenter_imported_name
    created_at updated_at
  ].freeze

  def snapshot_attributes
    SNAPSHOT_COLUMNS.each_with_object({}) do |col, hash|
      val = self[col]
      hash[col] = val.respond_to?(:iso8601) ? val.iso8601 : val
    end
  end

  private

  ##
  # Helper to fetch the permissions the reviewing user has on the review's project
  def project_permissions
    user.effective_permissions(rule.component)
  end

  def validate_project_permissions
    return unless user && rule

    required_tier = ACTION_PERMISSIONS[action]
    return if required_tier.nil? # inclusion validator catches unknown actions

    if project_permissions.blank?
      errors.add(:base, 'You have no permissions on this project')
      return
    end

    return if TIER_ROLES.fetch(required_tier).include?(project_permissions)

    errors.add(:base, "Insufficient permissions to #{action} on this component")
  end

  ##
  # should only be able to request review if
  # - current user is admin, reviewer, or author (viewers can only comment)
  # - not currently under review
  # - not currently locked
  def can_request_review
    perms = project_permissions
    if perms != 'admin' && perms != 'reviewer' && perms != 'author'
      errors.add(:base, 'Only admins, reviewers, and authors can request a review')
    elsif rule.locked
      errors.add(:base, 'Cannot request a review on a locked control')
    elsif !rule.review_requestor_id.nil?
      errors.add(:base, 'Control is already under review')
    end
  end

  ##
  # should only be able to revoke review request if
  # - current user is admin
  # - OR current user originally requested the review
  def can_revoke_review_request
    if rule.review_requestor_id.nil?
      errors.add(:base, 'Control is not currently under review')
    elsif !(user.id == rule.review_requestor_id || project_permissions == 'admin')
      errors.add(:base, 'Only the requestor or an admin can revoke a review request')
    end
  end

  ##
  # should only be able to request changes if
  # - current user is a reviewer or admin
  # - current user is reviewer and is not the review requestor
  # - control is currently under review
  def can_request_changes
    perms = project_permissions
    if rule.review_requestor_id.nil?
      errors.add(:base, 'Control is not currently under review')
    elsif perms != 'admin' && perms != 'reviewer'
      errors.add(:base, 'Only admins and reviewers can request changes')
    elsif perms == 'reviewer' && user.id == rule.review_requestor_id
      errors.add(:base, 'Reviewers cannot review their own review requests')
    end
  end

  ##
  # should only be able to approve if
  # - current user is a reviewer or admin
  # - current user is reviewer and is not the review requestor
  # - control is currently under review
  def can_approve
    perms = project_permissions
    if rule.review_requestor_id.nil?
      errors.add(:base, 'Control is not currently under review')
    elsif perms != 'admin' && perms != 'reviewer'
      errors.add(:base, 'Only admins and reviewers can approve')
    elsif perms == 'reviewer' && user.id == rule.review_requestor_id
      errors.add(:base, 'Reviewers cannot review their own review requests')
    end
  end

  ##
  # should only be able to lock control if
  # - current user is admin
  # - control is not under review
  # - control is not locked
  def can_lock_control
    if project_permissions != 'admin'
      errors.add(:base, 'Only an admin can lock')
    elsif !rule.review_requestor_id.nil?
      errors.add(:base, 'Cannot lock a control that is currently under review')
    elsif rule.locked
      errors.add(:base, 'Control is already locked')
    end
  end

  ##
  # should only be able to unlock a control if
  # - current user is admin
  # - control is locked
  def can_unlock_control
    if project_permissions != 'admin'
      errors.add(:base, 'Only an admin can unlock')
    elsif !rule.review_requestor_id.nil?
      errors.add(:base, 'Cannot unlock a control that is currently under review')
    elsif !rule.locked
      errors.add(:base, 'Control is already unlocked') unless rule.locked
    end
  end

  def default_triage_status_for_new_top_level_comment
    return if triage_status.present?
    return unless action == 'comment' && responding_to_review_id.nil?

    self.triage_status = 'pending'
  end

  def take_review_action
    case action
    when 'comment'
      # No rule-state mutation. The comment text is the entire payload.
      nil
    when 'request_review'
      set_rule_review_params(requestor_id: user.id, locked: false, changes_requested: false)
    when 'request_changes'
      set_rule_review_params(requestor_id: nil, locked: false, changes_requested: true)
    when 'revoke_review_request', 'unlock_control'
      set_rule_review_params(requestor_id: nil, locked: false, changes_requested: false)
    when 'approve', 'lock_control'
      set_rule_review_params(requestor_id: nil, locked: true, changes_requested: false)
    end
  end

  def set_rule_review_params(requestor_id:, locked:, changes_requested:)
    rule.review_requestor_id = requestor_id
    rule.locked = locked
    rule.changes_requested = changes_requested
    rule.save!
  end

  def duplicate_status_requires_target
    return unless triage_status == 'duplicate' && duplicate_of_review_id.blank?

    errors.add(:duplicate_of_review_id, 'is required when triage_status is duplicate')
  end

  def no_self_responding_reference
    return unless responding_to_review_id.present? && responding_to_review_id == id

    errors.add(:responding_to_review_id, 'cannot reference itself')
  end

  def no_self_duplicate_reference
    return unless duplicate_of_review_id.present? && duplicate_of_review_id == id

    errors.add(:duplicate_of_review_id, 'cannot reference itself')
  end

  # A thread reply (responding_to_review_id) only makes sense within
  # one rule's discussion. Without this guard a viewer could reply to
  # a comment on a different rule (or different component / project),
  # leaving an orphaned cross-rule thread reference in the audit trail.
  def responding_to_must_be_same_rule
    return if responding_to_review_id.blank?
    return if responding_to_review_id == id # self-ref handled separately

    parent = Review.where(id: responding_to_review_id).pick(:rule_id)
    return if parent.nil? # parent missing handled by belongs_to optionality / FK
    return if parent == rule_id

    errors.add(:responding_to_review_id, 'must reference a comment on the same rule')
  end

  # A duplicate marker (duplicate_of_review_id) must point to a
  # top-level comment within the SAME COMPONENT. Cross-component or
  # cross-project duplicate references are meaningless to a triager
  # and risk leaking review IDs across project boundaries.
  def duplicate_of_must_be_same_component
    return if duplicate_of_review_id.blank?
    return if duplicate_of_review_id == id # self-ref handled separately
    return if rule_id.blank?

    self_component_id = Rule.where(id: rule_id).pick(:component_id)
    target_component_id = Rule.joins(:reviews)
                              .where(reviews: { id: duplicate_of_review_id })
                              .pick('base_rules.component_id')
    return if self_component_id.nil? || target_component_id.nil?
    return if self_component_id == target_component_id

    errors.add(:duplicate_of_review_id, 'must reference a comment in the same component')
  end

  # Reject chained duplicates: a comment marked as duplicate of another
  # comment that is itself a duplicate. Forces triagers to point at the
  # ultimate canonical so the disposition matrix has a single coalescing
  # target per logical issue.
  def duplicate_of_must_not_be_a_duplicate
    return unless triage_status == 'duplicate' && duplicate_of_review_id.present?

    target_status = Review.where(id: duplicate_of_review_id).pick(:triage_status)
    return unless target_status == 'duplicate'

    errors.add(:duplicate_of_review_id, 'cannot point to another duplicate — pick the ultimate canonical')
  end

  def auto_set_adjudicated_for_terminal_statuses
    return unless TERMINAL_AUTO_ADJUDICATE_STATUSES.include?(triage_status)
    return if adjudicated_at.present?

    self.adjudicated_at = Time.current
    self.adjudicated_by_id ||= (triage_status == 'withdrawn' ? user_id : triage_set_by_id)
  end
end
