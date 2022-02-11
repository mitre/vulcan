# frozen_string_literal: true

# The BaseRule class is a simple class shared between SRG Rules and regular Component Rules.
# SRG Rules belong to an SRG, Component rules belong to a component and a SRG Rule
class BaseRule < ApplicationRecord
  amoeba do
    include_association :rule_descriptions
    include_association :disa_rule_descriptions
    include_association :checks
    include_association :references
    propagate
  end

  include RuleConstants
  include CciMap::Constants

  before_create :ensure_disa_description_exists
  before_create :ensure_check_exists

  has_many :rule_descriptions, dependent: :destroy
  has_many :disa_rule_descriptions, dependent: :destroy
  has_many :checks, dependent: :destroy
  has_many :references, dependent: :destroy

  accepts_nested_attributes_for :rule_descriptions, :disa_rule_descriptions, :checks, :references, allow_destroy: true

  validates :status, inclusion: {
    in: STATUSES,
    message: "is not an acceptable value, acceptable values are: '#{STATUSES.compact_blank.join("', '")}'"
  }

  validates :rule_severity, inclusion: {
    in: SEVERITIES,
    message: "is not an acceptable value, acceptable values are: '#{SEVERITIES.compact_blank.join("', '")}'"
  }

  # In all cases of has_many, it is very unlikely (based on past releases of SRGs
  # that there will be multiple of these fields. Just take the first one.
  # Extend the model if required

  # Reject legacy idents for the same reason, array of idents not established
  def self.from_mapping(rule_class, rule_mapping)
    rule = rule_class.new(
      rule_id: rule_mapping.id,
      status: rule_mapping.status.first&.status || 'Not Yet Determined',
      rule_severity: rule_mapping.severity || 'medium',
      rule_weight: rule_mapping.weight || '10.0',
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
    rule
  end

  ##
  # Override `as_json` to include dependent records
  #
  def as_json(options = {})
    super.merge(
      {
        rule_descriptions_attributes: rule_descriptions.as_json.map { |o| o.merge({ _destroy: false }) },
        disa_rule_descriptions_attributes: disa_rule_descriptions.as_json.map { |o| o.merge({ _destroy: false }) },
        checks_attributes: checks.as_json.map { |o| o.merge({ _destroy: false }) },
        nist_control_family: nist_control_family,
        version: version
      }
    )
  end

  def nist_control_family
    CCI_TO_NIST_CONSTANT[ident&.to_sym]
  end

  private

  def ensure_disa_description_exists
    return unless disa_rule_descriptions.size.zero?

    disa_rule_descriptions << DisaRuleDescription.new(base_rule: self)
  end

  def ensure_check_exists
    return unless checks.size.zero?

    checks << Check.new(base_rule: self)
  end
end
