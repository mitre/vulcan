# frozen_string_literal: true

# Serializes component-AUTHORED SrgRules for the editor.
#
# Deliberately NOT RuleBlueprint (its views call Rule-only methods —
# satisfies/satisfied_by, srg_rule, additional_answers) and NOT
# SrgRuleBlueprint (read-only nested catalog reference data with no
# status/reviews/locked). Authored requirements share the BaseRule
# surface: status, locking, reviews/comments, audit history, content.
#
# Views:
#   :navigator — sidebar rule list (default fields)
#   :editor    — full editing form (content + reviews + histories)
class AuthoredSrgRuleBlueprint < Blueprinter::Base
  identifier :id

  fields :rule_id, :title, :version, :status, :rule_severity, :locked,
         :review_requestor_id, :changes_requested

  field :comment_summary do |rule, _options|
    CommentSummaryField.summarize(rule)
  end

  view :navigator do
    # Default fields are sufficient for the navigator
  end

  # Read-only content (non-member show) — no reviews, no histories.
  view :viewer do
    fields :rule_weight, :fixtext, :fixtext_fixref, :ident, :ident_system,
           :vendor_comments, :vuln_id, :legacy_ids,
           :component_id, :status_justification, :artifact_description,
           :locked_fields

    field :nist_control_family do |rule, _options|
      rule.nist_control_family
    end

    # One kind-agnostic srg_id across document kinds: requirement lists
    # (the editor sidebar's SRG ID display and its sort) read rule.srg_id
    # regardless of kind. The model answers which value that is for this
    # kind — serializers never reconstruct it.
    field :srg_id do |rule, _options|
      rule.srg_identifier
    end

    # Portable lineage: the catalog requirement this row was derived from.
    field :derived_from_version do |rule, _options|
      rule.derived_from&.version
    end

    association :disa_rule_descriptions_attributes, blueprint: DisaRuleDescriptionBlueprint,
                                                    name: :disa_rule_descriptions_attributes do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.disa_rule_descriptions)
    end

    association :checks_attributes, blueprint: CheckBlueprint,
                                    name: :checks_attributes do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.checks)
    end

    association :rule_descriptions_attributes, blueprint: RuleDescriptionBlueprint,
                                               name: :rule_descriptions_attributes do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.rule_descriptions)
    end
  end

  view :editor do
    include_view :viewer

    field :histories do |rule, _options|
      rule.histories
    end

    association :reviews, blueprint: ReviewBlueprint do |rule, _options|
      ApplicationRecord.chronological(rule.reviews)
    end
  end
end
