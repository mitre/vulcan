# frozen_string_literal: true

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < ApplicationRecord
  include RuleConstants

  audited except: %i[project_id created_at updated_at locked], max_audits: 1000
  has_associated_audits

  before_validation :error_if_locked, on: :update
  before_destroy :error_if_locked

  has_many :comments, dependent: :destroy
  has_many :rule_descriptions, dependent: :destroy
  has_many :disa_rule_descriptions, dependent: :destroy
  has_many :checks, dependent: :destroy
  belongs_to :project

  accepts_nested_attributes_for :rule_descriptions, :disa_rule_descriptions, :checks, allow_destroy: true

  validates :status, inclusion: {
    in: STATUSES,
    message: "is not an acceptable value, acceptable values are: '#{STATUSES.reject(&:blank?).join("', '")}'"
  }

  validates :rule_severity, inclusion: {
    in: SEVERITIES,
    message: "is not an acceptable value, acceptable values are: '#{SEVERITIES.reject(&:blank?).join("', '")}'"
  }

  ##
  # Override `as_json` to include dependent records (e.g. comments, histories)
  #
  def as_json(options = {})
    super.merge(
      {
        comments: comments.as_json.map { |c| c.except('id', 'user_id', 'rule_id', 'updated_at') },
        histories: histories,
        rule_descriptions_attributes: rule_descriptions.as_json.map { |o| o.merge({ _destroy: false }) },
        disa_rule_descriptions_attributes: disa_rule_descriptions.as_json.map { |o| o.merge({ _destroy: false }) },
        checks_attributes: checks.as_json.map { |o| o.merge({ _destroy: false }) }
      }
    )
  end

  ##
  # Build a structure that minimally describes the editing history of a rule
  # and describes what can be reverted for that rule.
  #
  def histories
    own_and_associated_audits.order(:created_at).map do |audit|
      # Each audit can encompass multiple changes on the model (see audited_changes)
      {
        id: audit.id,
        action: audit.action,
        auditable_type: audit.auditable_type,
        auditable_id: audit.auditable_id,
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
    end
  end

  ##
  # Revert a specific field on a rule from an audit
  #
  # Parameters:
  #    rule (Rule) - A Rule object to revert a change on
  #    audit_id (integer) - A specific ID for an audited record
  #    field (string) - A specific field to revert from the audit record
  #
  def self.revert(rule, audit_id, field)
    audit = rule.own_and_associated_audits.find(audit_id)

    # nil check for audit
    raise(RuleRevertError, 'Could not locate history for this control.') if audit.nil?

    if audit.action == 'update'
      record = audit.auditable
      unless audit.audited_changes.include?(field)
        raise(RuleRevertError,
              'Field to revert does not exist in this history.')
      end

      record[field] =
        audit.audited_changes[field].is_a?(Array) ? audit.audited_changes[field][0] : audit.audited_changes[field]
      record.save
      return
    end

    raise(RuleRevertError, 'Cannot revert this history.') unless audit.action == 'destroy'

    auditable_type = case audit.auditable_type
                     when 'RuleDescription'
                       RuleDescription
                     when 'DisaRuleDescription'
                       DisaRuleDescription
                     when 'Check'
                       Check
                     else
                       raise(RuleRevertError, 'Cannot revert this history type.')
                     end
    begin
      auditable_type.create!(audit.audited_changes.merge({ rule_id: rule.id }))
    rescue ActiveRecord::RecordInvalid => e
      raise(RuleRevertError, "Encountered error while reverting this history. #{e.message}")
    end
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
