# frozen_string_literal: true

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < ApplicationRecord
  include RuleConstants

  audited except: %i[project_id created_at updated_at locked], max_audits: 1000
  before_validation :error_if_locked, on: :update
  before_destroy :error_if_locked

  has_associated_audits
  has_many :comments, dependent: :destroy
  has_many :rule_descriptions, dependent: :destroy
  has_many :disa_rule_descriptions, dependent: :destroy
  has_many :checks, dependent: :destroy
  belongs_to :project

  validates :status, inclusion: {
    in: STATUSES,
    message: "is not an acceptable value, acceptable values are: '#{STATUSES.reject(&:blank?).join("', '")}'"
  }

  validates :severity, inclusion: {
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
        rule_descriptions: rule_descriptions.as_json,
        disa_rule_descriptions: disa_rule_descriptions.as_json,
        checks: checks.as_json
      }
    )
  end

  ##
  # Build a structure that minimally describes the editing history of a rule
  # and describes what can be reverted for that rule.
  #
  def histories
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
