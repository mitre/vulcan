# frozen_string_literal: true

FactoryBot.define do
  sequence(:name) { |n| "John Doe#{n}" }
  sequence(:email) { |n| "user#{n}@example.org" }
  sequence(:password) { |n| "12345678#{n}" }
  sequence(:version) { |n| n }
  sequence(:release) { |n| n }
  sequence(:rule_id) { |n| n.to_s.rjust(6, '0') }
end
