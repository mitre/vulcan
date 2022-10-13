# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { generate(:name) }
    email { generate(:email) }
    password { generate(:password) }
    confirmed_at { Time.zone.now }
    confirmation_token { nil }

    trait :ldap_user do
      provider { 'ldap' }
      uid { '123456' }
    end

    trait :admin_user do
      admin { true }
    end

    factory :ldap_user, traits: [:ldap_user]

    factory :admin_user, traits: [:admin_user]
  end
end
