# frozen_string_literal: true

FactoryBot.define do
  factory :check do
    base_rule
    content { 'Verify the configuration meets requirements.' }
    system { 'http://cyber.mil/stigs' }
  end
end
