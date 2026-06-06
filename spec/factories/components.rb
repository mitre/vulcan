# frozen_string_literal: true

FactoryBot.define do
  factory :component do
    project { create(:project) }
    # Reuse existing SRG to avoid re-parsing 604KB XML + importing ~250 rules each time.
    # The SRG import is the single most expensive factory operation (~500ms per call).
    based_on { SecurityRequirementsGuide.first || create(:security_requirements_guide) }

    prefix { 'ABCD-00' }
    name { FFaker::Name.name }
    admin_name { generate(:name) }
    admin_email { generate(:email) }
    advanced_fields { false }
    version { generate(:version) }
    release { generate(:release) }
    title { 'Fake title' }
    description { 'Fake description' }

    # Lightweight component that skips the ~250 rule import from SRG.
    # Use when tests don't need actual SRG-derived rules (e.g., testing
    # component attributes, validations, permissions, or creating rules manually).
    # Saves ~200-500ms per create by skipping import_srg_rules callback.
    trait :skip_rules do
      skip_import_srg_rules { true }
    end

    trait :released_component do
      released { true }
    end

    trait :open_comment_period do
      comment_phase { 'open' }
      comment_period_starts_at { 1.day.ago }
      comment_period_ends_at { 14.days.from_now }
    end

    trait :closed_comment_phase do
      comment_phase { 'closed' }
      closed_reason { 'adjudicating' }
    end

    trait :with_poc do
      admin_name { 'Test Maintainer' }
      admin_email { 'maintainer@example.com' }
    end

    trait :released do
      released { true }
      after(:create) do |component|
        component.rules.update_all(locked: true)
      end
    end

    factory :released_component, traits: [:released_component]
  end
end
