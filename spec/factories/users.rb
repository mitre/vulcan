# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { generate(:name) }
    email { generate(:email) }
    password { generate(:password) }
    confirmed_at { Time.zone.now }
    confirmation_token { nil }

    transient do
      project_role { 'viewer' }
      project { nil }
    end

    trait :ldap_user do
      provider { 'ldap' }
      uid { '123456' }
    end

    trait :admin do
      admin { true }
    end

    trait :viewer do
      project_role { 'viewer' }
    end

    trait :author do
      project_role { 'author' }
    end

    trait :reviewer do
      project_role { 'reviewer' }
    end

    trait :with_membership do
      after(:create) do |user, evaluator|
        target_project = evaluator.project || create(:project)
        create(:membership, user: user, membership: target_project, role: evaluator.project_role)
      end
    end

    factory :ldap_user, traits: [:ldap_user]
  end
end
