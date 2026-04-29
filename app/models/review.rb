# frozen_string_literal: true

# Reviews on a specific Rule
class Review < ApplicationRecord
  belongs_to :user
  belongs_to :rule
  has_one :component, through: :rule

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
end
