# frozen_string_literal: true

XML_FILE = File.read('./spec/fixtures/files/U_A10_Networks_ADC_ALG_STIG_V2R1_Manual-xccdf.xml')

FactoryBot.define do
  factory :stig do
    stig_id { FFaker::Name.name.underscore }
    title { FFaker::Name.name }
    description { 'MyText' }
    version { "V#{rand(0..9)}R#{rand(0..9)}" }
    xml { XML_FILE }
    benchmark_date { '2023-07-20' }
  end
end
