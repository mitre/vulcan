# frozen_string_literal: true

# SrgRules are rules which belong to an SRG instad of a Control
class SrgRule < BaseRule
  amoeba do
    # This is used to clone SRGRules to Rules, easing the import process
    set type: Rule
    through :become_rule
  end

  belongs_to :security_requirements_guide

  def self.from_mapping(rule_mapping, srg_id)
    rule = super(self, rule_mapping)
    rule.security_requirements_guide_id = srg_id

    rule
  end

  private

  def become_rule
    dup.becomes(Rule)
  end
end
