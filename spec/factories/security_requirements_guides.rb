# frozen_string_literal: true

XML_FILE = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read

FactoryBot.define do
  factory :security_requirements_guide do
    sequence(:srg_id) { |n| "SRG-TEST-#{n.to_s.rjust(6, '0')}" }
    title { "Test Security Requirements Guide #{srg_id}" }
    sequence(:version) { |n| "V#{(n / 10) + 1}R#{(n % 10) + 1}" }
    xml { XML_FILE }
    release_date { Time.zone.today }
  end
end
