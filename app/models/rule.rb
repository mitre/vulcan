# frozen_string_literal: true

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < BaseRule
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

  belongs_to :component, counter_cache: true
  belongs_to :srg_rule
  belongs_to :review_requestor, class_name: 'User', inverse_of: :reviews, optional: true
  has_many :reviews, dependent: :destroy
  has_many :additional_answers, dependent: :destroy

  accepts_nested_attributes_for :additional_answers

  before_validation :set_rule_id
  before_save :apply_audit_comment
  before_destroy :prevent_destroy_if_under_review_or_locked

  validate :cannot_be_locked_and_under_review
  validate :review_fields_cannot_change_with_other_fields, on: :update

  validates :rule_id, allow_blank: false, presence: true, uniqueness: { scope: :component_id }

  def self.from_mapping(rule_mapping, component_id, idx, srg_rules)
    rule = super(self, rule_mapping)
    rule.audits.build(Audited.audit_class.create_initial_rule_audit_from_mapping(component_id))
    rule.component_id = component_id
    rule.srg_rule_id = srg_rules[rule.rule_id]
    # This is what is appended to the component prefix in the UI
    rule.rule_id = idx&.to_s&.rjust(6, '0')

    rule
  end

  ##
  # Override `as_json` to include parent SRG information
  #
  def as_json(options = {})
    super.merge(
      {
        reviews: reviews.as_json.map { |c| c.except('user_id', 'rule_id', 'updated_at') },
        srg_rule_attributes: srg_rule.as_json.except('id', 'locked', 'created_at', 'updated_at', 'status',
                                                     'status_justification', 'artifact_description',
                                                     'vendor_comments', 'rule_id', 'review_requestor_id',
                                                     'component_id', 'changes_requested', 'srg_rule_id',
                                                     'security_requirements_guide_id'),
        additional_answers_attributes: additional_answers.as_json.map do |c|
                                         c.except('rule_id', 'created_at', 'updated_at')
                                       end
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
        # The only field we can revert on AdditionalAnswers is answer
        field = 'answer' if audit.auditable_type.eql?('AdditionalAnswer')

        unless audit.audited_changes.include?(field)
          raise(RuleRevertError, "Field to revert (#{field.humanize}) does not exist in this history.")
        end

        # The audited change can either be an array `[prev_val, new_val]`
        # or just the `val`
        value = if audit.audited_changes[field].is_a?(Array)
                  audit.audited_changes[field][0]
                else
                  audit.audited_changes[field]
                end

        # Special case for AdditionalAnswer since it stores in the 'answer' field always
        if audit.auditable_type.eql?('AdditionalAnswer')
          record.answer = value
        else
          record[field] = value
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

  def csv_attributes
    [
      nist_control_family,
      ident,
      version,
      "#{component.prefix}-#{rule_id}",
      SEVERITIES_MAP[rule_severity] || rule_severity,
      srg_rule.title, # original srg title
      title,
      srg_rule.disa_rule_descriptions.first.vuln_discussion, # original srg vuln discussion
      disa_rule_descriptions.first.vuln_discussion,
      status,
      srg_rule.checks.first.content, # original SRG check content
      checks.first.content,
      srg_rule.fixtext, # original SRG fix text
      fixtext,
      status_justification,
      disa_rule_descriptions.first.mitigations,
      artifact_description,
      vendor_comments
    ]
  end

  private

  def cannot_be_locked_and_under_review
    return unless locked && review_requestor_id.present?

    errors.add(:base, 'Control cannot be under review and locked at the same time.')
  end

  ##
  # Check to ensure that "review fields" are not changed
  # in the same `.save` action as any "non-review fields"
  def review_fields_cannot_change_with_other_fields
    review_fields = Set.new(%w[review_requestor_id locked changes_requested])
    ignored_fields = %w[updated_at created_at]
    changed_filtered = changed.reject { |f| ignored_fields.include? f }
    any_review_fields_changed = changed_filtered.any? { |field| review_fields.include? field }
    any_non_review_fields_changed = changed_filtered.any? { |field| review_fields.exclude? field }
    # Break early if review and non-review fields have not changed together
    return unless any_review_fields_changed && any_non_review_fields_changed

    errors.add(:base, 'Cannot update review-related attributes with other non-review-related attributes')
  end

  def set_rule_id
    self.rule_id = (component.largest_rule_id + 1).to_s.rjust(6, '0') unless rule_id
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

    (rule_descriptions + disa_rule_descriptions + checks + additional_answers).each do |record|
      record.audit_comment = comment if record.new_record? || record.changed? || record._destroy
    end
  end
end
