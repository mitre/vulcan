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

  SEVERITIES_MAP = {
    'low' => 'CAT III',
    'medium' => 'CAT II',
    'high' => 'CAT I'
  }.freeze

  IMPACTS_MAP = {
    'low' => 0.3,
    'medium' => 0.5,
    'high' => 0.7
  }.freeze

  SEVERITIES = %w[
    unknown
    info
    low
    medium
    high
  ].freeze
end
