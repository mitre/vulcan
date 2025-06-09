# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { generate(:name) }
    email { generate(:email) }
    password { generate(:password) }
    confirmed_at { Time.zone.now }
    confirmation_token { nil }

    trait :admin do
      admin { true }
    end

    trait :ldap_user do
      provider { 'ldap' }
      uid { '123456' }
    end

    factory :admin_user, traits: [:admin]
    factory :ldap_user, traits: [:ldap_user]
  end
end
