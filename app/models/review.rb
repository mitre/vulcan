# frozen_string_literal: true

# Reviews on a specific Rule
class Review < ApplicationRecord
  include VulcanAuditable

  belongs_to :user
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
  vulcan_audited only: %i[triage_status adjudicated_by_id duplicate_of_review_id comment rule_id section]

  scope :top_level_comments, -> { where(action: 'comment', responding_to_review_id: nil) }
  scope :pending_triage, -> { top_level_comments.where(triage_status: 'pending') }
  scope :awaiting_adjudication, lambda {
    top_level_comments.where(triage_status: %w[concur concur_with_comment non_concur])
                      .where(adjudicated_at: nil)
  }

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
  validates :triage_status, inclusion: { in: TRIAGE_STATUSES }
  validates :section, inclusion: { in: SECTION_KEYS, message: 'is not a recognized section' },
                      allow_nil: true
  # rubocop:enable Rails/I18nLocaleTexts
  validate :duplicate_status_requires_target
  validate :no_self_responding_reference
  validate :no_self_duplicate_reference
  validate :responding_to_must_be_same_rule
  validate :duplicate_of_must_be_same_component
  validate :duplicate_of_must_not_be_a_duplicate

  before_save :auto_set_adjudicated_for_terminal_statuses

  before_create :take_review_action
  validate :validate_project_permissions
  validate :can_request_review, if: -> { action.eql? 'request_review' }
  validate :can_revoke_review_request, if: -> { action.eql? 'revoke_review_request' }
  validate :can_request_changes, if: -> { action.eql? 'request_changes' }
  validate :can_approve, if: -> { action.eql? 'approve' }
  validate :can_lock_control, if: -> { action.eql? 'lock_control' }
  validate :can_unlock_control, if: -> { action.eql? 'unlock_control' }

  delegate :name, to: :user

  ##
  # Serialization is handled by ReviewBlueprint.
  # See app/blueprints/review_blueprint.rb.

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
