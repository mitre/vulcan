# frozen_string_literal: true

# An SrgRule is either CATALOG (belongs to an imported SRG) or AUTHORED
# (belongs to an SRG-kind component being written in Vulcan) — never both,
# never neither. The database backs this with a type-scoped CHECK
# (base_rules_srg_authored_xor_catalog), because bulk SrgRule.import
# bypasses model validations.
class SrgRule < BaseRule
  amoeba do
    # This is used to clone SRGRules to Rules, easing the import process
    set type: Rule
    through :become_rule
  end

  include VulcanAuditable

  # Same wiring as Rule — authored SrgRules need identical auditing.
  # Catalog rows are unaffected in practice: bulk SrgRule.import bypasses
  # callbacks, so imports stay audit-free.
  vulcan_audited except: %i[component_id review_requestor_id inspec_control_file],
                 associated_with: :component
  has_associated_audits

  belongs_to :security_requirements_guide, optional: true
  belongs_to :component, optional: true, inverse_of: :authored_srg_rules
  belongs_to :derived_from, class_name: 'SrgRule',
                            foreign_key: :derived_from_srg_rule_id,
                            optional: true, inverse_of: false

  # Mirrors Rule's soft-delete scope. Lives HERE, not on BaseRule — a
  # BaseRule-level scope would newly filter StigRule reads.
  default_scope { where(deleted_at: nil) }

  validate :authored_xor_catalog
  # Authored rows validate against their component's profile vocabulary
  # (exact match); catalog rows keep the legacy superset via BaseRule so
  # published-XML statuses never break ingest.
  validate :authored_status_in_profile_vocabulary, if: :authored?
  # Marking an authored requirement Not Applicable records a decision —
  # the justification IS the record, so it is required here, not just in
  # the form. Catalog rows are untouched.
  validates :status_justification,
            presence: { message: :required_when_not_applicable },
            if: -> { authored? && status == RuleConstants::STATUS_NOT_APPLICABLE }

  def self.from_mapping(rule_mapping, srg_id)
    rule = super(self, rule_mapping)
    rule.security_requirements_guide_id = srg_id

    rule
  end

  private

  # An authored row belongs to a component. During a nested build (the
  # component copy path) the FK column stays nil until the parent saves,
  # so the in-memory association is part of the truth — keying only on
  # the column misclassified copied authored rows as catalog rows.
  def authored?
    component_id.present? || component.present?
  end

  # Catalog rows opt back into BaseRule's legacy inclusion; authored rows
  # are governed by the profile vocabulary below.
  def legacy_status_vocabulary?
    !authored?
  end

  def authored_status_in_profile_vocabulary
    vocabulary = AuthoringProfile.for(component.document_type).statuses
    return if vocabulary.include?(status)

    errors.add(:status,
               "is not an acceptable value, acceptable values are: '#{vocabulary.join("', '")}'")
  end

  def authored_xor_catalog
    catalog = security_requirements_guide_id.present? || security_requirements_guide.present?
    return if authored? != catalog

    errors.add(:base,
               'must belong to either a component (authored) or a security requirements guide (catalog), not both')
  end

  def become_rule
    dup.becomes(Rule)
  end
end
