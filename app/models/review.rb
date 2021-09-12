# frozen_string_literal: true

# Reviews on a specific Rule
class Review < ApplicationRecord
  belongs_to :user
  belongs_to :rule

  validates :user_id, :comment, :action, presence: true

  validate :take_review_action, on: :create

  delegate :name, to: :user

  ##
  # Override `as_json` to include delegated attributes
  #
  def as_json(options = {})
    super options.merge(methods: %i[name])
  end

  private

  def take_review_action
    project_permissions = user.project_permissions(rule.project)
    errors.add(:base, 'You have no permissions on this project') if project_permissions.blank?

    case action
    when 'request_review'
      # should only be able to request review if
      # - not currently under review
      # - not currently locked
      if rule.locked
        errors.add(:base, 'Cannot request a review on a locked control')
      elsif !rule.review_requestor_id.nil?
        errors.add(:base, 'Control is already under review')
      else
        rule.review_requestor_id = user.id
        rule.locked = false
        rule.save
      end
    when 'revoke_review_request'
      # should only be able to revoke review request if
      # - current user is admin
      # - OR current user originally requested the review
      if rule.review_requestor_id.nil?
        errors.add(:base, 'Control is not currently under review')
      elsif !(user.id == rule.review_requestor_id || project_permissions == 'admin')
        errors.add(:base, 'Only the requestor or an admin can revoke a review request')
      else
        rule.review_requestor_id = nil
        rule.locked = false
        rule.save
      end
    when 'request_changes'
      # should only be able to request changes if
      # - current user is a reviewer or admin
      # - control is currently under review
      if rule.review_requestor_id.nil?
        errors.add(:base, 'Control is not currently under review')
      elsif project_permissions != 'admin' && project_permissions != 'reviewer'
        errors.add(:base, 'Only admins and reviewers can request changes')
      else
        rule.review_requestor_id = nil
        rule.locked = false
        rule.save
      end
    when 'approve'
      # should only be able to approve if
      # - current user is a reviewer or admin
      # - control is currently under review
      if rule.review_requestor_id.nil?
        errors.add(:base, 'Control is not currently under review')
      elsif project_permissions != 'admin' && project_permissions != 'reviewer'
        errors.add(:base, 'Only admins and reviewers can approve')
      else
        rule.review_requestor_id = nil
        rule.locked = true
        rule.save
      end
    when 'lock_control'
      # should only be able to lock control if
      # - current user is admin
      # - control is not under review
      # - control is not locked
      if project_permissions != 'admin'
        errors.add(:base, 'Only an admin can lock')
      elsif !rule.review_requestor_id.nil?
        errors.add(:base, 'Cannot lock a control that is currently under review')
      elsif rule.locked
        errors.add(:base, 'Control is already locked')
      else
        rule.review_requestor_id = nil
        rule.locked = true
        rule.save
      end
    when 'unlock_control'
      # should only be able to unlock a control if
      # - current user is admin
      # - control is locked
      if project_permissions != 'admin'
        errors.add(:base, 'Only an admin can unlock')
      elsif !rule.review_requestor_id.nil?
        errors.add(:base, 'Cannot unlock a control that is currently under review')
      elsif !rule.locked
        errors.add(:base, 'Control is already unlocked') unless rule.locked
      else
        rule.review_requestor_id = nil
        rule.locked = false
        rule.save
      end
    end
  end
end
