# frozen_string_literal: true

# Constants that involve Rules
module RuleConstants
  STATUSES = [
    'Applicable - Configurable',
    'Applicable - Inherently Meets',
    'Applicable - Does Not Meet',
    'Not Applicable',
    nil
  ].freeze

  SEVERITIES = %w[
    unknown
    info
    low
    medium
    high
  ].freeze
end
