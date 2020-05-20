# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { generate(:name) }
    email { generate(:email) }
    password { '12345678' }
    confirmed_at { Time.zone.now }
    confirmation_token { nil }

    trait :ldap_user do
      provider { 'ldap' }
      uid { '123456' }
    end

    factory :ldap_user, traits: [:ldap_user]
  end
end
