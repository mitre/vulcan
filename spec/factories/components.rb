# frozen_string_literal: true

FactoryBot.define do
  factory :component do
    project { create(:project) }
    based_on { create(:security_requirements_guide) }

    prefix { 'ABCD-00' }
    name { FFaker::Name.name }
    released { true }
    admin_name { generate(:name) }
    admin_email { generate(:email) }
    advanced_fields { false }
    version { generate(:version) }
    release { generate(:release) }
    title { 'Fake title' }
    description { 'Fake description' }
  end
end
