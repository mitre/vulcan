# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    association :user
    association :membership, factory: :project
    role { 'viewer' }  # Default to viewer (valid role)

    trait :admin do
      role { 'admin' }
    end

    trait :reviewer do
      role { 'reviewer' }
    end

    trait :author do
      role { 'author' }
    end

    trait :component_membership do
      association :membership, factory: :component
    end
  end
end
