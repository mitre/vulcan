# frozen_string_literal: true

FactoryBot.define do
  factory :search_abbreviation do
    sequence(:abbreviation) { |n| "ABBR#{n}" }
    expansion { 'Test Expansion Text' }
    active { true }
    created_by { nil }

    trait :inactive do
      active { false }
    end

    trait :with_creator do
      created_by factory: %i[user]
    end
  end
end
