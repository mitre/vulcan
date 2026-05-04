# frozen_string_literal: true

# Serializes Rule records with context-specific views.
#
# Views:
#   :navigator — sidebar rule list (minimal fields for sorting/filtering)
#   :viewer    — read-only detail (adds text fields and nested associations)
#   :editor    — full editing form (adds reviews, SRG data, satisfactions)
#
# Replaces Rule#as_json and BaseRule#as_json overrides.
class RuleBlueprint < Blueprinter::Base
  identifier :id

  # === Default view: fields shared by ALL views ===
  fields :rule_id, :title, :version, :status, :rule_severity, :locked,
         :review_requestor_id, :changes_requested

  # per-rule comment summary surfaced on the navigator
  # so triagers can spot rules with pending comments without drilling in.
  # Computed in-memory against the eager-loaded :reviews association
  # (set_component already eager-loads rules → :reviews) so this is
  # zero additional queries. Top-level only — replies don't represent
  # new pending work.
  field :comment_summary do |rule, _options|
    top_level = rule.reviews.select do |r|
      r.action == 'comment' && r.responding_to_review_id.nil?
    end
    {
      pending: top_level.count { |r| r.triage_status == 'pending' },
      total: top_level.size
    }
  end

  # === Navigator view: sidebar list ===
  # Only fields needed for the rule navigator sidebar (sorting, filtering, badges).
  # No heavy text fields, no nested associations.
  view :navigator do
    # Default fields are sufficient for navigator
  end

  # === Viewer view: read-only detail ===
  view :viewer do
    fields :rule_weight, :fixtext, :fixtext_fixref, :ident, :ident_system,
           :vendor_comments, :vuln_id, :legacy_ids,
           :component_id, :status_justification, :artifact_description,
           :locked_fields

    field :nist_control_family do |rule, _options|
      rule.nist_control_family
    end

    field :srg_id do |rule, _options|
      rule.srg_rule&.version
    end

    association :disa_rule_descriptions_attributes, blueprint: DisaRuleDescriptionBlueprint,
                                                    name: :disa_rule_descriptions_attributes do |rule, _options|
      rule.disa_rule_descriptions
    end

    association :checks_attributes, blueprint: CheckBlueprint,
                                    name: :checks_attributes do |rule, _options|
      rule.checks
    end

    association :satisfies, blueprint: SatisfactionBlueprint do |rule, _options|
      rule.satisfies
    end

    association :satisfied_by, blueprint: SatisfiedByBlueprint do |rule, _options|
      rule.satisfied_by
    end
  end

  # === Editor view: full editing form ===
  view :editor do
    include_view :viewer

    fields :inspec_control_body, :inspec_control_file,
           :inspec_control_body_lang, :inspec_control_file_lang,
           :fix_id

    association :rule_descriptions_attributes, blueprint: RuleDescriptionBlueprint,
                                               name: :rule_descriptions_attributes do |rule, _options|
      rule.rule_descriptions
    end

    association :reviews, blueprint: ReviewBlueprint do |rule, _options|
      rule.reviews
    end

    association :additional_answers_attributes, blueprint: AdditionalAnswerBlueprint,
                                                name: :additional_answers_attributes do |rule, _options|
      rule.additional_answers
    end

    field :srg_rule_attributes do |rule, _options|
      SrgRuleBlueprint.render_as_hash(rule.srg_rule) if rule.srg_rule
    end

    field :srg_info do |rule, _options|
      { version: rule.srg_rule&.security_requirements_guide&.version }
    end
  end
end
