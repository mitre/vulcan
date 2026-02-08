# frozen_string_literal: true

FactoryBot.define do
  factory :stig_rule do
    stig
    sequence(:rule_id) { |n| "RHEL-09-#{654_000 + n}" }
    sequence(:vuln_id) { |n| "V-#{258_000 + n}" }
    title { 'Audit configuration changes' }
    status { 'Applicable - Configurable' }
    rule_severity { 'medium' }
    rule_weight { '10.0' }
    version { 'RHEL-09-654215r926638_rule' }
    fixtext { 'Configure the system to use auditing.' }
  end
end
