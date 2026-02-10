# frozen_string_literal: true

# Optimized JSON for STIG detail view (BenchmarkViewer)
# Bypasses BaseRule.as_json overhead by directly extracting needed fields

json.extract! @stig, :id, :stig_id, :title, :version, :benchmark_date

json.stig_rules @stig.stig_rules do |rule|
  # Core fields for RuleList and navigation
  json.extract! rule, :id, :rule_id, :title, :version, :rule_severity, :srg_id, :vuln_id, :legacy_ids, :ident, :nist_control_family

  # Content fields for RuleDetails
  json.extract! rule, :fixtext, :vendor_comments

  # Nested associations for RuleDetails (only needed fields)
  json.disa_rule_descriptions_attributes rule.disa_rule_descriptions do |desc|
    json.extract! desc, :vuln_discussion
  end

  json.checks_attributes rule.checks do |check|
    json.extract! check, :content
  end
end
