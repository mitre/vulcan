# frozen_string_literal: true

FactoryBot.define do
  factory :project_access_request do
    user { nil }
    project { nil }
  end
end
