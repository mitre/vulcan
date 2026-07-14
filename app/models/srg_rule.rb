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

  def self.from_mapping(rule_mapping, srg_id)
    rule = super(self, rule_mapping)
    rule.security_requirements_guide_id = srg_id

    rule
  end

  private

  def authored_xor_catalog
    return if component_id.nil? != security_requirements_guide_id.nil?

    errors.add(:base,
               'must belong to either a component (authored) or a security requirements guide (catalog), not both')
  end

  def become_rule
    dup.becomes(Rule)
  end
end
