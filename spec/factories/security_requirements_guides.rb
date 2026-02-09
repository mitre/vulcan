# frozen_string_literal: true

XML_FILE = File.read(Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml'))

FactoryBot.define do
  factory :security_requirements_guide do
    srg_id { FFaker::Name.name.underscore }
    title { FFaker::Name.name }
    version { "V#{rand(0..9)}R#{rand(0..9)}" }
    xml { XML_FILE }
    release_date { Time.zone.today }
  end
end
