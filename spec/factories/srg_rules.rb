# frozen_string_literal: true

FactoryBot.define do
  factory :srg_rule do
    security_requirements_guide
    sequence(:rule_id) { |n| "SV-#{200_000 + n}r#{800_000 + n}_rule" }
    title { 'The application must enforce approved authorizations' }
    status { 'Applicable - Configurable' }
    rule_severity { 'medium' }
    rule_weight { '10.0' }
    sequence(:version) { |n| "SRG-APP-#{format('%06d', n)}-GPOS-00001" }
    fixtext { 'Configure the application to enforce approved authorizations.' }
    ident { 'CCI-000366' }

    # Component-authored requirement (no catalog parent). Authored rows
    # live on srg-kind components and validate against the SRG profile
    # vocabulary; pass component: to attach to a specific one.
    trait :authored do
      security_requirements_guide { nil }
      component { create(:component, :skip_rules, document_type: 'srg') }
      status { 'Not Yet Determined' }
    end
  end
end
