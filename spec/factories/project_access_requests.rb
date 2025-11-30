# frozen_string_literal: true

FactoryBot.define do
  factory :project_access_request do
    user
    project
  end
end
