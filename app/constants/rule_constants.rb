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

  STATUS_APPLICABLE_CONFIGURABLE = STATUSES[1]

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
    low
    medium
    high
  ].freeze

  LOCKABLE_SECTION_NAMES = [
    'Title', 'Severity', 'Status', 'Fix', 'Check',
    'Vulnerability Discussion', 'DISA Metadata',
    'Vendor Comments', 'Artifact Description', 'XCCDF Metadata'
  ].freeze
end
