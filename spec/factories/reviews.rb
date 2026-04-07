# frozen_string_literal: true

FactoryBot.define do
  factory :review do
    user
    rule
    action { 'request_review' }
    comment { 'Requesting review' }
  end
end
