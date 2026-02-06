# frozen_string_literal: true

FactoryBot.define do
  factory :srg_rule do
    security_requirements_guide
    sequence(:rule_id) { |n| "SV-#{200000 + n}r#{800000 + n}_rule" }
    title { 'The application must enforce approved authorizations' }
    status { 'Applicable - Configurable' }
    rule_severity { 'medium' }
    rule_weight { '10.0' }
    sequence(:version) { |n| "SRG-APP-#{format('%06d', n)}-GPOS-00001" }
    fixtext { 'Configure the application to enforce approved authorizations.' }
    ident { 'CCI-000366' }
  end
end
