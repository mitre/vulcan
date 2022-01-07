# frozen_string_literal: true

module ImportConstants
  IMPORT_MAPPING = {
    srg_id: 'SRGID',
    stig_id: 'STIG ID',
    rule_severity: 'Severity',
    title: 'Requirement',
    vuln_discussion: 'VulDiscussion',
    status: 'Status',
    check_content: 'Check',
    fixtext: 'Fix',
    vendor_comments: 'Vendor Comments',
    status_justification: 'Status Justification',
    artifact_description: 'Artifact Description'
  }.freeze
end
