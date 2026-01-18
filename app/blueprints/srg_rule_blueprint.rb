# frozen_string_literal: true

class SrgRuleBlueprint < Blueprinter::Base
  identifier :id

  fields :rule_id,
         :version,
         :title,
         :ident,
         :ident_system,
         :fixtext,
         :fixtext_fixref,
         :fix_id,
         :rule_severity,
         :rule_weight

  association :disa_rule_descriptions, blueprint: DisaRuleDescriptionBlueprint
  association :checks, blueprint: CheckBlueprint
end
