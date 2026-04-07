# frozen_string_literal: true

# Serializes StigRule records for STIG show pages.
# Similar to SrgRuleBlueprint but for published STIG rules.
class StigRuleBlueprint < Blueprinter::Base
  identifier :id

  fields :rule_id, :title, :version, :rule_severity, :rule_weight,
         :ident, :ident_system, :fixtext, :fixtext_fixref, :fix_id,
         :vuln_id, :legacy_ids

  association :disa_rule_descriptions_attributes, blueprint: DisaRuleDescriptionBlueprint,
                                                  name: :disa_rule_descriptions_attributes do |rule, _options|
    rule.disa_rule_descriptions
  end

  association :checks_attributes, blueprint: CheckBlueprint,
                                  name: :checks_attributes do |rule, _options|
    rule.checks
  end
end
