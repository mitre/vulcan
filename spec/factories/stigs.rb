# frozen_string_literal: true

XML_FILE_STIG = Rails.root.join('db/seeds/stigs/U_RHEL_9_STIG_V2R7_Manual-xccdf.xml').read

FactoryBot.define do
  factory :stig do
    stig_id { FFaker::Name.name.underscore }
    name { FFaker::Name.name }
    title { FFaker::Name.name }
    description { 'MyText' }
    version { "V#{rand(0..9)}R#{rand(0..9)}" }
    xml { XML_FILE_STIG }
    benchmark_date { '2023-07-20' }
  end
end
