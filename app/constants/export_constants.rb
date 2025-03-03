# frozen_string_literal: true

module ExportConstants
  DISA_EXPORT_HEADERS = ['IA Control', 'CCI', 'SRGID', 'STIGID', 'SRG Requirement', 'Requirement',
                         'SRG VulDiscussion', 'VulDiscussion', 'Status', 'SRG Check', 'Check', 'SRG Fix',
                         'Fix', 'Severity', 'Mitigation', 'Status Justification', 'Artifact Description', 'Vendor Comments'].freeze
  OPTIONAL_EXPORT_HEADERS = ['InSpec Control Body'].freeze

  EXPORT_HEADERS = [DISA_EXPORT_HEADERS, OPTIONAL_EXPORT_HEADERS].flatten.freeze
end
