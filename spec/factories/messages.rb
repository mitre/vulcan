# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    body { 'test' }
    user
  end
end
