# frozen_string_literal: true

# Serializes component-AUTHORED SrgRules for the editor. Inherits the shared
# requirement surface from BaseRuleBlueprint (identifier, default fields,
# comment_summary, navigator, picker head, viewer head + srg_id, and the
# :content_attributes composition) and adds only the authored-kind surface:
# portable lineage (derived_from_version), the content attributes, and
# reviews/histories.
#
# Deliberately NOT the same as RuleBlueprint (its views call Rule-only methods —
# satisfies/satisfied_by, srg_rule, additional_answers) and NOT SrgRuleBlueprint
# (read-only nested catalog reference data with no status/reviews/locked). The
# shared BaseRule surface — status, locking, reviews/comments, audit history,
# content — comes from the base; only the Rule-only extras are absent here.
#
# srg_id is inherited from BaseRuleBlueprint unchanged: an authored requirement
# holds the identifier in its own version column (Category 1, no preload), which
# is exactly the base default — so this blueprint does not re-declare it.
#
# Views:
#   :navigator — sidebar rule list (inherited; default fields)
#   :picker    — RulePicker dropdown (inherited head; no satisfaction graph)
#   :viewer    — read-only content (lineage + content attrs)
#   :editor    — full editing form (content + reviews + histories)
#
# PRELOAD DECLARATIONS — every block-bearing entry states its category; see
# BaseRuleBlueprint for the full scheme.
class AuthoredSrgRuleBlueprint < BaseRuleBlueprint
  # === Picker view: shared component-scoped display name, nothing more ===
  # Re-opened (even though it adds no fields of its own) because Blueprinter
  # only carries a parent view's fields into a subclass that re-declares that
  # view — without this, the inherited base picker's displayed_name is dropped
  # from the authored picker payload. Authored requirements have no satisfaction
  # graph, so no satisfies/satisfied_by here.
  view :picker do
    # No fields of its own — the re-open exists solely to pull in the inherited
    # base picker (displayed_name). See the comment above.
  end

  # === Viewer view: portable lineage + shared content attributes ===
  view :viewer do
    # Category 3 — portable lineage, reaching the catalog requirement this row
    # was derived from. Sits between srg_id and the content attributes, matching
    # the authored requirement list's display order.
    field :derived_from_version, preload: :derived_from do |rule, _options|
      rule.derived_from&.version
    end

    include_view :content_attributes

    # Category 3 by name. Authored requirements surface rule_descriptions in the
    # read-only viewer (a Rule surfaces them only in its editor).
    association :rule_descriptions_attributes, blueprint: RuleDescriptionBlueprint,
                                               name: :rule_descriptions_attributes,
                                               preload: :rule_descriptions do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.rule_descriptions)
    end
  end

  # === Editor view: content + collaboration ===
  view :editor do
    include_view :viewer

    # Opt-in, because it cannot be batched and is only ever displayed for one
    # requirement at a time. The audit trail is not an association — it is a
    # union of the record's own audits and those recorded against it as an
    # associated record, built per instance — so no preload can fetch it for a
    # whole collection. The per-requirement endpoint asks for it; the collection
    # does not. (Category 0.)
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
