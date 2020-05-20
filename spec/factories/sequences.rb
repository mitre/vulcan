# frozen_string_literal: true

FactoryBot.define do
  sequence(:name) { |n| "John Doe#{n}" }
  sequence(:email) { |n| "user#{n}@example.org" }
end
