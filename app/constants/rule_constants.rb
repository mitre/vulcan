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

  # Maps each lockable field to its section name.
  # Mirrors LOCKABLE_SECTIONS / FIELD_TO_SECTION in ruleFieldConfig.js — keep in sync.
  SECTION_FIELDS = {
    'Title' => %i[title],
    'Severity' => %i[rule_severity severity_override_guidance],
    'Status' => %i[status status_justification],
    'Fix' => %i[fixtext fix_id fixtext_fixref],
    'Check' => %i[check_content content system content_ref_name content_ref_href],
    'Vulnerability Discussion' => %i[vuln_discussion],
    'DISA Metadata' => %i[documentable false_positives false_negatives mitigations_available
                          mitigations poam_available poam potential_impacts third_party_tools
                          mitigation_control responsibility ia_controls],
    'Vendor Comments' => %i[vendor_comments],
    'Artifact Description' => %i[artifact_description],
    'XCCDF Metadata' => %i[version rule_weight ident ident_system]
  }.freeze

  # Reverse lookup: field_sym → section name
  FIELD_TO_SECTION = SECTION_FIELDS.each_with_object({}) do |(section, fields), map|
    fields.each { |f| map[f] = section }
  end.freeze
end
