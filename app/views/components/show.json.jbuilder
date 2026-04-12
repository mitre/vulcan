# frozen_string_literal: true

# Lightweight JSON for Component detail view — non-member access (BenchmarkViewer).
# Bypasses BaseRule.as_json overhead with a custom rule shape that the
# RuleBlueprint :viewer view does not produce.
#
# Editor (project member) refreshes are served by ComponentBlueprint :editor
# directly from ComponentsController#show — see that action for the rationale.

# Non-member viewing released component - lightweight for BenchmarkViewer
json.extract! @component, :id, :name, :prefix, :version, :release, :updated_at
json.based_on_title @component.based_on.title
json.based_on_version @component.based_on.version

# Lightweight rules for viewer (same pattern as STIG/SRG)
json.rules @component.rules, cached: true do |rule|
  json.extract! rule, :id, :rule_id, :title, :version, :rule_severity, :vuln_id, :legacy_ids, :ident, :nist_control_family, :fixtext, :vendor_comments
  json.srg_id rule.srg_rule&.version

  json.satisfies rule.satisfies do |s|
    json.extract! s, :id, :rule_id
    json.srg_id s.srg_rule&.version
  end

  json.satisfied_by rule.satisfied_by do |s|
    json.extract! s, :id, :rule_id, :fixtext
    json.srg_id s.srg_rule&.version
  end

  json.disa_rule_descriptions_attributes rule.disa_rule_descriptions do |desc|
    json.extract! desc, :vuln_discussion
  end

  json.checks_attributes rule.checks do |check|
    json.extract! check, :content
  end
end

json.reviews @component.reviews
