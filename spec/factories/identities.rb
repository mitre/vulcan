# frozen_string_literal: true

FactoryBot.define do
  factory :identity do
    user
    provider { 'oidc' }
    sequence(:uid) { |n| "uid-#{n}" }
    email { user.email }
  end
end
