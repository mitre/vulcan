# frozen_string_literal: true

FactoryBot.define do
  factory :rule do
    component { create(:component) }
    srg_rule { create(:srg_rule) }

    status { 'Not Yet Determined' }
    rule_severity { 'medium' }
    rule_weight { '10.0' }
  end
end
