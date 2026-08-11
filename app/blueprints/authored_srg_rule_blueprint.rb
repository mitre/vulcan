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
#
# PRELOAD DECLARATIONS — same categories as RuleBlueprint, which carries the
# full explanation. In short: (1) reads a column, needs nothing; (2) an
# association under its real reflection name, resolves on its own; (3) a field
# whose block reaches an association, or an association named something the
# model does not know, MUST carry `preload:` or its plan is silently empty;
# (0) the audit trail, which is not an association and cannot be batched at all.
# Every declaration that carries a block states its category; the bare `fields`
# macros need none, having no block through which to reach an association.
class AuthoredSrgRuleBlueprint < Blueprinter::Base
  identifier :id

  fields :rule_id, :title, :version, :status, :rule_severity, :locked,
         :review_requestor_id, :changes_requested

  # Category 3: the block reads reviews, which nothing outside it can infer.
  field :comment_summary, preload: :reviews do |rule, _options|
    CommentSummaryField.summarize(rule)
  end

  view :navigator do
    # Default fields are sufficient for the navigator
  end

  # RulePicker dropdown — defaults plus the component-scoped display name.
  # Authored requirements have no satisfaction graph, so the satisfies /
  # satisfied_by keys are omitted entirely (consumers default with || []).
  view :picker do
    # Category 3: builds its name from the owning component's prefix.
    field :displayed_name, preload: :component do |rule, _options|
      rule.displayed_name
    end
  end

  # Read-only content (non-member show) — no reviews, no histories.
  view :viewer do
    fields :rule_weight, :fixtext, :fixtext_fixref, :ident, :ident_system,
           :vendor_comments, :vuln_id, :legacy_ids,
           :component_id, :status_justification, :artifact_description,
           :locked_fields

    # Category 1: derives from the ident column, reaching nothing.
    field :nist_control_family do |rule, _options|
      rule.nist_control_family
    end

    # One kind-agnostic srg_id across document kinds: requirement lists
    # (the editor sidebar's SRG ID display and its sort) read rule.srg_id
    # regardless of kind. The model answers which value that is for this
    # kind — serializers never reconstruct it. CATEGORY 1: an authored
    # requirement holds the identifier in its own version column, where a Rule
    # would have to reach its source requirement for it.
    field :srg_id do |rule, _options|
      rule.srg_identifier
    end

    # Category 3 — portable lineage, reaching the catalog requirement this row
    # was derived from.
    field :derived_from_version, preload: :derived_from do |rule, _options|
      rule.derived_from&.version
    end

    # Category 3 by name, all three — the `_attributes` keys match no model
    # association, so each names the real one.
    association :disa_rule_descriptions_attributes, blueprint: DisaRuleDescriptionBlueprint,
                                                    name: :disa_rule_descriptions_attributes,
                                                    preload: :disa_rule_descriptions do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.disa_rule_descriptions)
    end

    association :checks_attributes, blueprint: CheckBlueprint,
                                    name: :checks_attributes,
                                    preload: :checks do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.checks)
    end

    # Category 3 by name.
    association :rule_descriptions_attributes, blueprint: RuleDescriptionBlueprint,
                                               name: :rule_descriptions_attributes,
                                               preload: :rule_descriptions do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.rule_descriptions)
    end
  end

  view :editor do
    include_view :viewer

    # Opt-in, because it cannot be batched and is only ever displayed for one
    # requirement at a time. The audit trail is not an association — it is a
    # union of the record's own audits and those recorded against it as an
    # associated record, built per instance — so no preload can fetch it for a
    # whole collection. Serializing it for every requirement cost one query per
    # row to produce data the page shows for the selected row alone. The
    # per-requirement endpoint asks for it; the collection does not.
    field :histories,
          if: ->(_field, _rule, options) { options && options[:include_histories] } do |rule, _options|
      rule.histories
    end

    # Category 2.
    association :reviews, blueprint: ReviewBlueprint do |rule, _options|
      ApplicationRecord.chronological(rule.reviews)
    end
  end
end
