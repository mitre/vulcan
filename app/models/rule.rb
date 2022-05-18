# frozen_string_literal: true

require 'inspec/objects'

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < BaseRule
  amoeba do
    # Using set review_requestor_id: nil does not work as expected, must use nullify
    nullify :review_requestor_id
    set locked: false

    include_association :additional_answers
  end

  audited except: %i[component_id review_requestor_id created_at updated_at locked inspec_control_file],
          max_audits: 1000,
          associated_with: :component
  has_associated_audits

  belongs_to :component
  belongs_to :srg_rule
  belongs_to :review_requestor, class_name: 'User', inverse_of: :reviews, optional: true
  has_many :reviews, dependent: :destroy
  has_many :additional_answers, dependent: :destroy

  accepts_nested_attributes_for :additional_answers

  has_and_belongs_to_many :satisfied_by,
                          class_name: 'Rule',
                          join_table: :rule_satisfactions,
                          association_foreign_key: :satisfied_by_rule_id

  has_and_belongs_to_many :satisfies,
                          class_name: 'Rule',
                          join_table: :rule_satisfactions,
                          foreign_key: :satisfied_by_rule_id,
                          association_foreign_key: :rule_id

  before_validation :set_rule_id
  before_save :apply_audit_comment
  before_save :update_inspec_code
  before_destroy :prevent_destroy_if_under_review_or_locked
  after_destroy :update_component_rules_count
  after_save :update_component_rules_count
  after_save :update_satisfied_by_inspec_code

  validates_with RuleSatisfactionValidator
  validate :cannot_be_locked_and_under_review
  validate :review_fields_cannot_change_with_other_fields, on: :update

  validates :rule_id, allow_blank: false, presence: true, uniqueness: { scope: :component_id }

  default_scope { where(deleted_at: nil) }

  def self.from_mapping(rule_mapping, component_id, idx, srg_rules)
    rule = super(self, rule_mapping)
    rule.audits.build(Audited.audit_class.create_initial_rule_audit_from_mapping(component_id))
    rule.component_id = component_id
    rule.srg_rule_id = srg_rules[rule.rule_id]
    # This is what is appended to the component prefix in the UI
    rule.rule_id = idx&.to_s&.rjust(6, '0')

    rule
  end

  # Overrides for satisfied controls
  def status
    satisfied_by.size.positive? ? 'Applicable - Configurable' : self[:status]
  end

  def status=(value)
    super(value) unless satisfied_by.size.positive?
  end

  ##
  # Override `as_json` to include parent SRG information
  #
  def as_json(options = {})
    result = super(options)
    unless options[:skip_merge].eql?(true)
      result = result.merge(
        {
          reviews: reviews.as_json.map { |c| c.except('user_id', 'rule_id', 'updated_at') },
          srg_rule_attributes: srg_rule.as_json.except('id', 'locked', 'created_at', 'updated_at', 'status',
                                                       'status_justification', 'artifact_description',
                                                       'vendor_comments', 'review_requestor_id',
                                                       'component_id', 'changes_requested', 'srg_rule_id',
                                                       'security_requirements_guide_id'),
          satisfies: satisfies.as_json(only: %i[id rule_id], skip_merge: true),
          satisfied_by: satisfied_by.as_json(only: %i[id fixtext rule_id], skip_merge: true),
          additional_answers_attributes: additional_answers.as_json.map do |c|
                                           c.except('rule_id', 'created_at', 'updated_at')
                                         end
        }
      )
    end

    result
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
      export_checktext,
      srg_rule.fixtext, # original SRG fix text
      export_fixtext,
      status_justification,
      disa_rule_descriptions.first.mitigations,
      artifact_description,
      vendor_comments_with_satisfactions
    ]
  end

  def displayed_name
    "#{component[:prefix]}-#{rule_id}"
  end

  def update_inspec_code
    desc = disa_rule_descriptions.first
    control = Inspec::Object::Control.new
    control.add_header('# -*- encoding : utf-8 -*-')
    control.id = "#{component[:prefix]}-#{rule_id}"
    control.title = title
    control.descriptions[:default] = desc[:vuln_discussion] if desc.present?
    control.descriptions[:rationale] = ''
    control.descriptions[:check] = checks.first&.content
    control.descriptions[:fix] = fixtext
    control.impact = RuleConstants::IMPACTS_MAP[rule_severity]
    control.add_tag(Inspec::Object::Tag.new('severity', rule_severity))
    control.add_tag(Inspec::Object::Tag.new('gtitle', version))
    control.add_tag(Inspec::Object::Tag.new('satisfies', satisfies.pluck(:version).sort)) if satisfies.present?
    control.add_tag(Inspec::Object::Tag.new('gid', nil))
    control.add_tag(Inspec::Object::Tag.new('rid', nil))
    control.add_tag(Inspec::Object::Tag.new('stig_id', "#{component[:prefix]}-#{rule_id}"))
    control.add_tag(Inspec::Object::Tag.new('cci', ([ident] + satisfies.pluck(:ident)).uniq.sort)) if ident.present?
    control.add_tag(Inspec::Object::Tag.new('nist', ([nist_control_family] +
                                                      satisfies.map(&:nist_control_family)).uniq.sort))
    if desc.present?
      %i[false_negatives false_positives documentable mitigations severity_override_guidance potential_impacts
         third_party_tools mitigation_control responsibility ia_controls].each do |field|
        control.add_tag(Inspec::Object::Tag.new(field.to_s, desc[field])) if desc[field].present?
      end
    end
    control.add_post_body(inspec_control_body) if inspec_control_body.present?
    self.inspec_control_file = control.to_ruby
  end

  def update_satisfied_by_inspec_code
    sb = satisfied_by.first
    return if sb.nil?

    # trigger update_inspec_code callback
    sb.save
  end

  def basic_fields
    {
      rule_id: rule_id,
      title: title,
      vuln_discussion: disa_rule_descriptions.first&.vuln_discussion,
      check: export_checktext,
      fix: export_fixtext
    }
  end

  private

  def export_fixtext
    satisfied_by.size.positive? ? satisfied_by.first.fixtext : fixtext
  end

  def export_checktext
    satisfied_by.size.positive? ? satisfied_by.first.checks.first&.content : checks.first&.content
  end

  def vendor_comments_with_satisfactions
    comments = []
    comments << vendor_comments if vendor_comments.present?

    if satisfied_by.present?
      comments << "Satisfied By: #{satisfied_by.map { |r| "#{component.prefix}-#{r.rule_id}" }.join(', ')}."
    end

    if satisfies.present?
      comments << "Satisfies: #{satisfies.map { |r| "#{component.prefix}-#{r.rule_id}" }.join(', ')}."
    end

    comments.join('. ')
  end

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
    self.rule_id = (component.largest_rule_id + 1).to_s.rjust(6, '0') if rule_id.blank?
  end

  ##
  # Rules should never be deleted if they are under review or locked
  # This checks *_was to cover the case where an attrubute was changed before attempting to destroy
  def prevent_destroy_if_under_review_or_locked
    # Allow deletion if it is due to the parent being deleted
    return if destroyed_by_association.present?

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

  def update_component_rules_count
    component.rules_count = component.rules.where(deleted_at: nil).size
    component.save
  end
end
