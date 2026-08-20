# frozen_string_literal: true

FactoryBot.define do
  factory :personal_access_token do
    user
    sequence(:name) { |n| "Token #{n}" }
    scopes { %w[read write] }
    expires_at { 30.days.from_now.to_date }
  end
end
