# frozen_string_literal: true

FactoryBot.define do
  factory :check do
    # Use stig_rule as the base_rule association (STI pattern)
    association :base_rule, factory: :stig_rule
    content { 'Verify the configuration meets requirements.' }
    system { 'http://cyber.mil/stigs' }
  end
end
