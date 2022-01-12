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
    mitigation: 'Mitigation'
  }.freeze

  IMPORT_MAPPING = REQUIRED_MAPPING_CONSTANTS.merge(OPTIONAL_MAPPING_CONSTANTS)
end
