# frozen_string_literal: true

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < ApplicationRecord
  audited except: %i[project_id created_at updated_at locked], max_audits: 1000
  before_validation :error_if_locked, on: :update
  before_destroy :error_if_locked

  has_many :comments, dependent: :destroy
  belongs_to :project

  ##
  # Override `as_json` to include dependent records (e.g. comments, histories)
  #
  def as_json(options = {})
    super.merge({ comments: comments.as_json, histories: history })
  end

  ##
  # Build a structure that minimally describes the editing history of a rule
  # and describes what can be reverted for that rule.
  #
  def history
    audits.order(:created_at).map do |audit|
      # Each audit can encompass multiple changes on the model (see audited_changes)
      # `[0...-1]` removes the last audit from the list because the last element
      # is the current state of the rule.
      {
        id: audit.id,
        name: audit.user&.name || 'Unknown User',
        created_at: audit.created_at,
        audited_changes: audit.audited_changes.map do |audited_field, audited_value|
          # On creation, the `audited_value` will be a single value (i.e. not an Array)
          # After an edit, the `audited_value` will be an Array where `[0]` is prev and `[1]` is new
          {
            field: audited_field,
            prev_value: (audited_value.is_a?(Array) ? audited_value[0] : nil),
            new_value: (audited_value.is_a?(Array) ? audited_value[1] : audited_value)
          }
        end
      }
    end[0...-1]
  end

  ##
  # Revert a specific field on a rule from an audit
  #
  # Parameters:
  #    audit (Audited::Audit) - A specific audited record
  #    field (string) - A specific field to revert from the audit record
  #
  def self.revert(user, audit, field)
    # nil check for audit
    raise(RuleRevertError('unknown', field)) if audit.nil?

    # `audit.auditable` refers to the rule itself
    rule = audit.auditable

    # Ensure `auditable` is indeed a rule
    raise(RuleRevertError('unknown', field)) unless rule.is_a?(Rule)

    # Permissions check for revert
    raise(RuleRevertError(rule, field)) unless user.can_edit_project?(rule.project)

    # Check that desired field exists in the audit
    raise(RuleRevertError(rule, field)) unless audit.audited_changes.include?(field)

    rule[field] = audit.audited_changes[field]
    rule.save
  end

  # Allow an authorized user to unlock a rule
  def self.unlock(user, rule)
    # Can a user manage the project this rule is part of?
    raise(RuleLockedError, rule.id) unless user.can_admin_project?(rule.project)

    # update_attribute bypasses validations on purpose to unlock the rule
    # rubocop:disable Rails/SkipsModelValidations
    rule.update_attribute(:locked, false)
    # rubocop:enable Rails/SkipsModelValidations
  end

  private

  def error_if_locked
    # locked = current update
    # locked_was = before
    # If the previous state was not locked, updates can be made.
    return unless locked_was

    # If the previous state was locked, error
    raise(RuleLockedError, id) if locked_was
  end
end
