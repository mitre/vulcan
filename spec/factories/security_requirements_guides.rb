# frozen_string_literal: true

XML_FILE = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read

FactoryBot.define do
  factory :security_requirements_guide do
    sequence(:srg_id) { |n| "SRG-TEST-#{n.to_s.rjust(6, '0')}" }
    title { "Test Security Requirements Guide #{srg_id}" }
    sequence(:version) { |n| "V#{(n / 10) + 1}R#{(n % 10) + 1}" }
    xml { XML_FILE }
    release_date { Time.zone.today }

    # A core-family SRG — the non-public raw material SRG-kind components
    # derive from (never a valid STIG parent).
    trait :core do
      core { true }
    end

    # Lightweight SRG that skips the ~250 rule import from the XML fixture.
    # Use when tests hand-craft srg_rules (e.g., pinning severity counts).
    # Same pattern as the stig factory's :skip_rules trait.
    trait :skip_rules do
      after(:build) { |srg| srg.define_singleton_method(:import_srg_rules) { nil } }
    end
  end
end
