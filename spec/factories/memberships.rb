# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    user
    membership factory: :project
    role { 'viewer' }

    trait :admin do
      role { 'admin' }
    end

    trait :author do
      role { 'author' }
    end

    trait :reviewer do
      role { 'reviewer' }
    end

    trait :for_component do
      membership factory: :component
    end
  end
end
