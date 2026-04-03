# frozen_string_literal: true

# Optimized JSON for SRG detail view (BenchmarkViewer)
# Bypasses BaseRule.as_json overhead by directly extracting needed fields

json.extract! @srg, :id, :srg_id, :title, :version, :release_date

json.srg_rules @srg.srg_rules, cached: true do |rule|
  # Core fields for RuleList and navigation
  json.extract! rule, :id, :rule_id, :title, :version, :rule_severity, :ident, :nist_control_family

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
