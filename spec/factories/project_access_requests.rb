# frozen_string_literal: true

FactoryBot.define do
  factory :project_access_request do
    user { create(:user) }
    project { create(:project) }
  end
end
