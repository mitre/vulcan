# frozen_string_literal: true

XML_FILE = File.read('./spec/fixtures/files/U_Web_Server_V2R3_Manual-xccdf.xml')

FactoryBot.define do
  factory :security_requirements_guide do
    srg_id { FFaker::Name.name.underscore }
    title { FFaker::Name.name }
    version { "V#{rand(0..9)}R#{rand(0..9)}" }
    xml { XML_FILE }
    release_date { Time.zone.today }
  end
end
