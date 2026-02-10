# frozen_string_literal: true

# Optimized JSON for Component detail view (full editor or BenchmarkViewer)
# For BenchmarkViewer: Bypasses BaseRule.as_json overhead
# For full editor: Includes additional data (reviews, memberships, etc.)

if @effective_permissions
  # Project member viewing component - full data for editor
  json.extract! @component, :id, :name, :prefix, :version, :release, :title, :description,
                :admin_name, :admin_email, :released, :advanced_fields
  json.based_on_title @component.based_on.title
  json.based_on_version @component.based_on.version
  json.releasable @component.releasable
  json.additional_questions @component.additional_questions
  json.histories @component.histories
  json.memberships @component.memberships
  json.metadata @component.metadata
  json.inherited_memberships @component.inherited_memberships
  json.available_members @component.available_members
  json.admins @component.admins
  json.all_users @component.all_users
  json.reviews @component.reviews

  # Full rules for editor
  json.rules @component.rules do |rule|
    json.merge! rule.as_json # Use full as_json for editor
  end
else
  # Non-member viewing released component - lightweight for BenchmarkViewer
  json.extract! @component, :id, :name, :prefix, :version, :release, :updated_at
  json.based_on_title @component.based_on.title
  json.based_on_version @component.based_on.version

  # Lightweight rules for viewer (same pattern as STIG/SRG)
  json.rules @component.rules, cached: true do |rule|
    json.extract! rule, :id, :rule_id, :title, :version, :rule_severity, :srg_id, :vuln_id, :legacy_ids, :ident, :nist_control_family, :fixtext, :vendor_comments

    json.disa_rule_descriptions_attributes rule.disa_rule_descriptions do |desc|
      json.extract! desc, :vuln_discussion
    end

    json.checks_attributes rule.checks do |check|
      json.extract! check, :content
    end
  end

  json.reviews @component.reviews
end
