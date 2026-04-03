# frozen_string_literal: true

module ImportConstants
  REQUIRED_MAPPING_CONSTANTS = {
    srg_id: 'SRGID',
    stig_id: 'STIGID',
    rule_severity: 'Severity',
    title: 'Requirement',
    vuln_discussion: 'VulDiscussion',
    status: 'Status',
    check_content: 'Check',
    fixtext: 'Fix',
    status_justification: 'Status Justification',
    artifact_description: 'Artifact Description'
  }.freeze

  OPTIONAL_MAPPING_CONSTANTS = {
    vendor_comments: 'Vendor Comments',
    mitigation: 'Mitigation',
    inspec_control_body: 'InSpec Control Body',
    ident: 'CCI',
    satisfies: 'Satisfies'
  }.freeze

  IMPORT_MAPPING = REQUIRED_MAPPING_CONSTANTS.merge(OPTIONAL_MAPPING_CONSTANTS)

  # Postel's Law: Be liberal in what we accept.
  # Accept both standard DISA import headers AND benchmark CSV export headers.
  # Maps benchmark export header names to their DISA import equivalents.
  HEADER_ALIASES = {
    'STIG ID' => 'STIGID',
    'SRG ID' => 'SRGID',
    'Title' => 'Requirement',
    'Description' => 'VulDiscussion',
    'Vuln Discussion' => 'VulDiscussion',
    'Mitigations' => 'Mitigation',
    'Check Content' => 'Check',
    'Fix Text' => 'Fix'
  }.freeze
end
