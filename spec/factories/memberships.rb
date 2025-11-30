# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    user
    membership factory: %i[project]
    role { 'viewer' } # Default to viewer (valid role)

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
      membership factory: %i[component]
    end
  end
end
