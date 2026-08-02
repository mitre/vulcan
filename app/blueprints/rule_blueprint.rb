# frozen_string_literal: true

# Serializes Rule records with context-specific views.
#
# Views:
#   :navigator — sidebar rule list (minimal fields for sorting/filtering)
#   :viewer    — read-only detail (adds text fields and nested associations)
#   :editor    — full editing form (adds reviews, SRG data, satisfactions)
#
# Replaces Rule#as_json and BaseRule#as_json overrides.
#
# PRELOAD DECLARATIONS — every entry below states which of these it is, and
# knowing which prevents both a silent N+1 and a wasted query. The extension
# builds its plan by matching a declared association's name against the model's
# own reflections; it cannot see inside a block.
#   1. Reads a column only — needs nothing. Annotating it would preload data
#      no one asks for.
#   2. An association declared under its real reflection name — resolves on
#      its own. Renaming one silently costs the preload along with the name.
#   3. Anything else — a field whose block reaches an association, or an
#      association declared under a name the model does not know (the
#      `_attributes` keys, which exist because they are the payload contract
#      form consumers read) — MUST carry `preload:`, naming the real
#      association. Without it the plan is silently empty for that entry.
#   0. One entry fits none of them: the audit trail is not an association, so
#      no annotation can batch it. It is marked as such where it appears.
# Every declaration that carries a block states its category, so a reader never
# has to infer one and a new field cannot quietly skip the question. The bare
# `fields` macros need no marker: they read attributes directly and have no
# block through which an association could ever be reached.
class RuleBlueprint < Blueprinter::Base
  identifier :id

  # === Default view: fields shared by ALL views ===
  fields :rule_id, :title, :version, :status, :rule_severity, :locked,
         :review_requestor_id, :changes_requested

  # Category 3 — the block reads reviews, which nothing outside it can infer.
  # Per-rule comment summary surfaced on the navigator + section icon badges.
  # One shared definition across document kinds — see CommentSummaryField for
  # the "open" semantics.
  field :comment_summary, preload: :reviews do |rule, _options|
    CommentSummaryField.summarize(rule)
  end

  # === Navigator view: sidebar list ===
  # Only fields needed for the rule navigator sidebar (sorting, filtering, badges).
  # No heavy text fields, no nested associations.
  view :navigator do
    # Default fields are sufficient for navigator
  end

  # === Picker view: RulePicker dropdown ===
  # Navigator defaults + satisfaction relationship IDs for parent/child badges.
  # No text blobs, no reviews, no checks — just enough for the picker UI.
  view :picker do
    # Category 3: builds its name from the owning component's prefix.
    field :displayed_name, preload: :component do |rule, _options|
      rule.displayed_name
    end

    # Category 2, here and in the viewer view below.
    association :satisfies, blueprint: SatisfactionBlueprint do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.satisfies)
    end

    association :satisfied_by, blueprint: SatisfactionBlueprint do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.satisfied_by)
    end
  end

  # === Viewer view: read-only detail ===
  view :viewer do
    fields :rule_weight, :fixtext, :fixtext_fixref, :ident, :ident_system,
           :vendor_comments, :vuln_id, :legacy_ids,
           :component_id, :status_justification, :artifact_description,
           :locked_fields

    # Category 1: derives from the ident column, reaching nothing.
    field :nist_control_family do |rule, _options|
      rule.nist_control_family
    end

    # Category 3: a Rule answers for its SRG identifier by reaching its source
    # requirement, unlike an authored requirement which holds the value itself.
    field :srg_id, preload: :srg_rule do |rule, _options|
      rule.srg_identifier
    end

    # Category 3 by name, this pair — the `_attributes` keys match no model
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

    # Category 2, both of them.
    association :satisfies, blueprint: SatisfactionBlueprint do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.satisfies)
    end

    association :satisfied_by, blueprint: SatisfiedByBlueprint do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.satisfied_by)
    end
  end

  # === Editor view: full editing form ===
  view :editor do
    include_view :viewer

    fields :inspec_control_body, :inspec_control_file,
           :inspec_control_body_lang, :inspec_control_file_lang,
           :fix_id

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

    # Category 3 by name.
    association :rule_descriptions_attributes, blueprint: RuleDescriptionBlueprint,
                                               name: :rule_descriptions_attributes,
                                               preload: :rule_descriptions do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.rule_descriptions)
    end

    # Category 2.
    association :reviews, blueprint: ReviewBlueprint do |rule, _options|
      ApplicationRecord.chronological(rule.reviews)
    end

    # Category 3 by name.
    association :additional_answers_attributes, blueprint: AdditionalAnswerBlueprint,
                                                name: :additional_answers_attributes,
                                                preload: :additional_answers do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.additional_answers)
    end

    # Category 3, declaring the source requirement AND what gets read from it.
    # This is a field rather than an association, so the extension cannot follow
    # it into SrgRuleBlueprint and discover that nested content on its own —
    # preloading only the source requirement would still leave its checks and
    # descriptions to be fetched one requirement at a time.
    field :srg_rule_attributes,
          preload: { srg_rule: %i[checks disa_rule_descriptions rule_descriptions] } do |rule, _options|
      SrgRuleBlueprint.render_as_json(rule.srg_rule) if rule.srg_rule
    end

    # Category 3, reaching one step further than the others: through the source
    # requirement to the guide it came from.
    field :srg_info, preload: { srg_rule: :security_requirements_guide } do |rule, _options|
      { version: rule.srg_rule&.security_requirements_guide&.version }
    end
  end
end
