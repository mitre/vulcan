# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    name { generate(:name) }
  end
end
