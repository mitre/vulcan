# frozen_string_literal: true

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < ApplicationRecord
  include RuleConstants
  include CciMap::Constants

  amoeba do
    include_association :rule_descriptions
    include_association :disa_rule_descriptions
    include_association :checks
    include_association :references
    # Using set review_requestor_id: nil does not work as expected, must use nullify
    nullify :review_requestor_id
    set locked: false
  end

  audited except: %i[component_id review_requestor_id created_at updated_at locked], max_audits: 1000
  has_associated_audits

  before_save :apply_audit_comment
  before_create :ensure_disa_description_exists
  before_create :ensure_check_exists
  before_destroy :prevent_destroy_if_under_review_or_locked

  has_many :reviews, dependent: :destroy
  has_many :rule_descriptions, dependent: :destroy
  has_many :disa_rule_descriptions, dependent: :destroy
  has_many :checks, dependent: :destroy
  has_many :references, dependent: :destroy
  belongs_to :component, counter_cache: true
  belongs_to :review_requestor, class_name: 'User', inverse_of: :reviews, optional: true

  accepts_nested_attributes_for :rule_descriptions, :disa_rule_descriptions, :checks, :references, allow_destroy: true

  validate :cannot_be_locked_and_under_review,
           :component_must_not_be_released
  validate :review_fields_cannot_change_with_other_fields, on: :update

  validates :status, inclusion: {
    in: STATUSES,
    message: "is not an acceptable value, acceptable values are: '#{STATUSES.reject(&:blank?).join("', '")}'"
  }

  validates :rule_severity, inclusion: {
    in: SEVERITIES,
    message: "is not an acceptable value, acceptable values are: '#{SEVERITIES.reject(&:blank?).join("', '")}'"
  }

  validates :rule_id, allow_blank: false, presence: true

  # In all cases of has_many, it is very unlikely (based on past releases of SRGs
  # that there will be multiple of these fields. Just take the first one.
  # Extend the model if required

  # Reject legacy idents for the same reason, array of idents not established
  def self.from_mapping(rule_mapping, component_id)
    rule = Rule.new(
      component_id: component_id,
      rule_id: rule_mapping.id,
      status: rule_mapping.status.first&.status || 'Not Yet Determined',
      rule_severity: rule_mapping.severity || nil,
      rule_weight: rule_mapping.weight || nil,
      version: rule_mapping.version.first&.version,
      title: rule_mapping.title.first || nil,
      ident: rule_mapping.ident.reject(&:legacy).first.ident,
      ident_system: rule_mapping.ident.reject(&:legacy).first.system,
      fixtext: rule_mapping.fixtext.first&.fixtext,
      fixtext_fixref: rule_mapping.fixtext.first&.fixref,
      fix_id: rule_mapping.fix.first&.id
    )
    rule.references.build(Reference.from_mapping(rule_mapping.reference.first))
    rule.disa_rule_descriptions.build(DisaRuleDescription.from_mapping(rule_mapping.description.first))
    rule.checks.build(Check.from_mapping(rule_mapping.check.first))
    rule.audits.build(Audited.audit_class.create_initial_rule_audit_from_mapping(component_id))
    rule
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

  ##
  # Override `as_json` to include dependent records
  #
  def as_json(options = {})
    super.merge(
      {
        reviews: reviews.as_json.map { |c| c.except('user_id', 'rule_id', 'updated_at') },
        rule_descriptions_attributes: rule_descriptions.as_json.map { |o| o.merge({ _destroy: false }) },
        disa_rule_descriptions_attributes: disa_rule_descriptions.as_json.map { |o| o.merge({ _destroy: false }) },
        checks_attributes: checks.as_json.map { |o| o.merge({ _destroy: false }) }
      }
    )
  end

  def csv_attributes
    [
      CCI_TO_NIST_CONSTANT[ident.to_sym],
      ident,
      version,
      "#{component.prefix}-#{id}",
      rule_severity,
      nil, # original srg title
      title,
      nil, # original srg vuln discussion
      disa_rule_descriptions.first.vuln_discussion,
      status,
      nil, # original SRG check content
      checks.first.content,
      nil, # original SRG fix text
      fixtext,
      status_justification,
      disa_rule_descriptions.first.mitigation_control, # should be another field
      artifact_description,
      vendor_comments
    ]
  end

  private

  def component_must_not_be_released
    return unless component.released

    errors.add(:base, 'Cannot make modifications to a component that has been released')
  end

  def cannot_be_locked_and_under_review
    return unless locked && review_requestor_id.present?

    errors.add(:base, 'Control cannot be under review and locked at the same time.')
  end

  ##
  # Check to ensure that "review fields" are not changed
  # in the same `.save` action as any "non-review fields"
  def review_fields_cannot_change_with_other_fields
    review_fields = Set.new(%w[review_requestor_id locked])
    ignored_fields = %w[updated_at created_at]
    changed_filtered = changed.reject { |f| ignored_fields.include? f }
    any_review_fields_changed = changed_filtered.any? { |field| review_fields.include? field }
    any_non_review_fields_changed = changed_filtered.any? { |field| review_fields.exclude? field }
    # Break early if review and non-review fields have not changed together
    return unless any_review_fields_changed && any_non_review_fields_changed

    errors.add(:base, 'Cannot update review-related attributes with other non-review-related attributes')
  end

  ##
  # Rules should never be deleted if they are under review or locked
  # This checks *_was to cover the case where an attrubute was changed before attempting to destroy
  def prevent_destroy_if_under_review_or_locked
    # Abort if under review and trying to delete
    if review_requestor_id_was.present?
      errors.add(:base, 'Control is under review and cannot be destroyed')
      throw(:abort)
    end

    # Abort if locked and trying to delete
    return unless locked_was

    errors.add(:base, 'Control is locked and cannot be destroyed')
    throw(:abort)
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
