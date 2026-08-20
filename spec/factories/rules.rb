# frozen_string_literal: true

FactoryBot.define do
  factory :rule do
    component { create(:component, :skip_rules) }
    # Route through the FK column, not component.based_on: that association
    # is select-scoped WITHOUT :id, so based_on.srg_rules matches nothing on
    # refound records and creating from it wrote an ORPHAN catalog row
    # (NULL srg FK) — rejected by SrgRule's authored-XOR-catalog validation.
    srg_rule do
      srg_id = component.security_requirements_guide_id
      (srg_id && SrgRule.find_by(security_requirements_guide_id: srg_id)) ||
        create(:srg_rule, security_requirements_guide_id: srg_id)
    end
    sequence(:rule_id) { |n| format('%06d', n) }
    status { 'Not Yet Determined' }
    rule_severity { 'medium' }
    version { 'ABCD-00-000001' }
    ident { 'CCI-000366' }
    title { 'Test Rule' }

    trait :locked do
      locked { true }
    end

    trait :applicable_configurable do
      status { 'Applicable - Configurable' }
    end

    trait :not_applicable do
      status { 'Not Applicable' }
    end

    trait :not_yet_determined do
      status { 'Not Yet Determined' }
    end
  end
end
