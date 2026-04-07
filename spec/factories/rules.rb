# frozen_string_literal: true

FactoryBot.define do
  factory :rule do
    component { create(:component, :skip_rules) }
    srg_rule { component.based_on.srg_rules.first || create(:srg_rule, security_requirements_guide: component.based_on) }
    sequence(:rule_id) { |n| format('%06d', n) }
    status { 'Not Yet Determined' }
    rule_severity { 'medium' }
    version { 'ABCD-00-000001' }
    ident { 'CCI-000366' }
    title { 'Test Rule' }
  end
end
