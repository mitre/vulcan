# frozen_string_literal: true

FactoryBot.define do
  factory :project_access_request do
    association :user
    association :project
  end
end
