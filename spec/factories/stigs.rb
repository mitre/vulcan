# frozen_string_literal: true

XML_FILE_STIG = Rails.root.join('db/seeds/stigs/U_RHEL_9_STIG_V2R7_Manual-xccdf.xml').read

FactoryBot.define do
  factory :stig do
    sequence(:stig_id) { |n| "STIG-TEST-#{n.to_s.rjust(6, '0')}" }
    sequence(:name) { |n| "Test STIG #{n}" }
    sequence(:title) { |n| "Test Security Technical Implementation Guide #{n}" }
    description { 'MyText' }
    sequence(:version) { |n| "V#{(n / 10) + 1}R#{(n % 10) + 1}" }
    xml { XML_FILE_STIG }
    benchmark_date { '2023-07-20' }
  end
end
