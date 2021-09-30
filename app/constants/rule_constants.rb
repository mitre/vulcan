# frozen_string_literal: true

# Constants that involve Rules
module RuleConstants
  STATUSES = [
    'Not Yet Determined',
    'Applicable - Configurable',
    'Applicable - Inherently Meets',
    'Applicable - Does Not Meet',
    'Not Applicable'
  ].freeze

  SEVERITIES = %w[
    unknown
    info
    low
    medium
    high
  ].freeze
end
