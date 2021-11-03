# frozen_string_literal: true

# SrgRules are rules which belong to an SRG instad of a Control
class SrgRule < BaseRule
  belongs_to :security_requirements_guide

  def self.from_mapping(rule_mapping, srg_id)
    rule = super(self, rule_mapping)
    rule.security_requirements_guide_id = srg_id

    rule
  end
end
