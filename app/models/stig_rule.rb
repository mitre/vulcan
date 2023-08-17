# frozen_string_literal: true

# SrgRules are rules which belong to an SRG instad of a Control
class StigRule < BaseRule
  belongs_to :stig

  def self.from_mapping(group_mapping, stig_id)
    rule = super(self, group_mapping.rule.first)
    rule.stig_id = stig_id
    rule.srg_id = group_mapping.title.first
    rule.vuln_id = group_mapping.id
    rule
  end
end
