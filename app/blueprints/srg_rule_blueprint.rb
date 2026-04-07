# frozen_string_literal: true

# Serializes an SRG rule (the original SRG requirement that a Rule implements).
# Used as nested data inside RuleBlueprint :editor view for the srg_rule_attributes field.
# Excludes internal fields that the editor doesn't need (id, locked, timestamps, etc.).
class SrgRuleBlueprint < Blueprinter::Base
  # No identifier — this is always nested, never fetched by ID

  fields :rule_id, :title, :version, :rule_severity, :rule_weight,
         :ident, :ident_system, :fixtext, :fixtext_fixref, :fix_id,
         :inspec_control_body, :inspec_control_file,
         :inspec_control_body_lang, :inspec_control_file_lang,
         :vuln_id, :legacy_ids

  association :rule_descriptions_attributes, blueprint: RuleDescriptionBlueprint,
                                             name: :rule_descriptions_attributes do |srg_rule, _options|
    srg_rule.rule_descriptions
  end

  association :disa_rule_descriptions_attributes, blueprint: DisaRuleDescriptionBlueprint,
                                                  name: :disa_rule_descriptions_attributes do |srg_rule, _options|
    srg_rule.disa_rule_descriptions
  end

  association :checks_attributes, blueprint: CheckBlueprint,
                                  name: :checks_attributes do |srg_rule, _options|
    srg_rule.checks
  end
end
