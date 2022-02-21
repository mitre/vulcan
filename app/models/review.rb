# frozen_string_literal: true

# Reviews on a specific Rule
class Review < ApplicationRecord
  belongs_to :user
  belongs_to :rule
  has_one :component, through: :rule

  validates :comment, :action, presence: true

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
  # Override `as_json` to include delegated attributes
  #
  def as_json(options = {})
    super options.merge(methods: %i[name])
  end

  private

  ##
  # Helper to fetch the permissions the reviewing user has on the review's project
  def project_permissions
    user.effective_permissions(rule.component)
  end

  def validate_project_permissions
    errors.add(:base, 'You have no permissions on this project') if project_permissions.blank?
  end

  ##
  # should only be able to request review if
  # - not currently under review
  # - not currently locked
  def can_request_review
    if rule.locked
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
