# frozen_string_literal: true

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < ApplicationRecord
  include RuleConstants

  audited except: %i[project_id created_at updated_at locked], max_audits: 1000
  has_associated_audits

  before_validation :error_if_locked, on: :update
  before_save :apply_audit_comment
  before_create :ensure_disa_description_exists
  before_create :ensure_check_exists
  before_destroy :error_if_locked

  has_many :comments, dependent: :destroy
  has_many :rule_descriptions, dependent: :destroy
  has_many :disa_rule_descriptions, dependent: :destroy
  has_many :checks, dependent: :destroy
  has_many :references, dependent: :destroy
  belongs_to :project

  accepts_nested_attributes_for :rule_descriptions, :disa_rule_descriptions, :checks, :references, allow_destroy: true

  validates :status, inclusion: {
    in: STATUSES,
    message: "is not an acceptable value, acceptable values are: '#{STATUSES.reject(&:blank?).join("', '")}'"
  }

  validates :rule_severity, inclusion: {
    in: SEVERITIES,
    message: "is not an acceptable value, acceptable values are: '#{SEVERITIES.reject(&:blank?).join("', '")}'"
  }

  validates :rule_id,
            uniqueness: {
              scope: :project_id,
              message: 'already exists for this project'
            },
            allow_blank: false

  # In all cases of has_many, it is very unlikely (based on past releases of SRGs
  # that there will be multiple of these fields. Just take the first one.
  # Extend the model if required

  # Reject legacy idents for the same reason, array of idents not established
  def self.from_mapping(rule_mapping)
    Rule.new(
      rule_id: rule_mapping.id,
      status: rule_mapping.status.first&.status,
      rule_severity: rule_mapping.severity || nil,
      rule_weight: rule_mapping.weight || nil,
      version: rule_mapping.version.first&.version,
      title: rule_mapping.title.first || nil,
      ident: rule_mapping.ident.reject(&:legacy).first.ident,
      ident_system: rule_mapping.ident.reject(&:legacy).first.system,
      fixtext: rule_mapping.fixtext.first&.fixtext,
      fixtext_fixref: rule_mapping.fixtext.first&.fixref,
      fix_id: rule_mapping.fix.first&.id,
      references: [Reference.from_mapping(rule_mapping.reference.first)]
    )
  end

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
  # Revert a specific field on a rule from an audit
  #
  # Parameters:
  #    rule (Rule) - A Rule object to revert a change on
  #    audit_id (integer) - A specific ID for an audited record
  #    field (string) - A specific field to revert from the audit record
  #
  def self.revert(rule, audit_id, fields, audit_comment)
    audit = rule.own_and_associated_audits.find(audit_id)

    # nil check for audit
    raise(RuleRevertError, 'Could not locate history for this control.') if audit.nil?

    if audit.action == 'update'
      record = audit.auditable

      # nil check for record
      raise(RuleRevertError, 'Could not locate record for this history.') if record.nil?

      fields.each do |field|
        unless audit.audited_changes.include?(field)
          raise(RuleRevertError, "Field to revert (#{field.humanize}) does not exist in this history.")
        end

        # The audited change can either be an array `[prev_val, new_val]`
        # or just the `val`
        record[field] = if audit.audited_changes[field].is_a?(Array)
                          audit.audited_changes[field][0]
                        else
                          audit.audited_changes[field]
                        end
      end
      record.audit_comment = audit_comment if record.changed?
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
      auditable_type.create!(audit.audited_changes.merge({ rule_id: rule.id, audit_comment: audit_comment }))
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

  def ensure_disa_description_exists
    return unless disa_rule_descriptions.size.zero?

    disa_rule_descriptions << DisaRuleDescription.new(rule: self)
  end

  def ensure_check_exists
    return unless checks.size.zero?

    checks << Check.new(rule: self)
  end

  ##
  # This before_save callback method exists because if there are no changes on a record, but a audit_comment
  # is provided, then an Audited::Audit record will be created with no audited_changes. This makes histories
  # unnecessarily confusing.
  #
  # This method addresses that issue by checking the record and its dependent records to see if they are
  # new records, changed, or marked for deletion. If any of those criteria are true, then the audited_comment
  # will be applied ONLY to the correct places.
  #
  def apply_audit_comment
    comment = audit_comment
    return if comment.nil?

    self.audit_comment = nil unless new_record? || changed?

    (rule_descriptions + disa_rule_descriptions + checks).each do |record|
      record.audit_comment = comment if record.new_record? || record.changed? || record._destroy
    end
  end
end
