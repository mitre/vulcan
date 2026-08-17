# frozen_string_literal: true

# Shared serialization surface for requirement rows across document kinds —
# both STIG Rules (RuleBlueprint) and component-authored SRG requirements
# (AuthoredSrgRuleBlueprint) inherit it. It holds ONLY what the two render
# identically and in the same position: the identifier, the default field set,
# the comment summary, the navigator/picker heads, the viewer's leading block
# (content fields + nist_control_family + srg_id), and the two shared content
# associations (as the :content_attributes composition target). Kind-specific
# fields and the views whose field ORDER diverges (each subclass's editor, and
# the viewer tail) stay in the subclasses, so the serialized output is
# byte-for-byte unchanged from before this base existed.
#
# srg_id lives here WITHOUT a preload — the kind-agnostic default, correct for
# an authored requirement, which holds the identifier in its own version column.
# A Rule reaches its source requirement for the same value, so RuleBlueprint
# OVERRIDES srg_id in place to add `preload: :srg_rule`. Blueprinter orders a
# field by its first definition, so the override keeps srg_id's inherited
# position while swapping in the preload — same output, only the batch plan
# differs.
#
# PRELOAD DECLARATIONS — every block-bearing entry states its category. The
# extension builds its plan by matching a declared association's name against
# the model's own reflections; it cannot see inside a block.
#   1. Reads a column only — needs nothing.
#   2. An association under its real reflection name — resolves on its own.
#   3. A field whose block reaches an association, or an association declared
#      under a name the model does not know (the `_attributes` keys, which exist
#      because they are the payload contract form consumers read) — MUST carry
#      `preload:`, naming the real association, or its plan is silently empty.
#   0. The audit trail is not an association and cannot be batched, so it is not
#      here — it lives in the subclass editors where it is used.
# The bare `fields` macros need no marker: they read attributes directly and
# have no block through which an association could ever be reached.
class BaseRuleBlueprint < Blueprinter::Base
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
  # Only the default fields are needed for the rule navigator sidebar.
  view :navigator do
    # Default fields are sufficient for navigator
  end

  # === Picker view: RulePicker dropdown (shared head) ===
  # The component-scoped display name. Kinds with a satisfaction graph (Rule)
  # append satisfies/satisfied_by in their own subclass.
  view :picker do
    # Category 3: builds its name from the owning component's prefix.
    field :displayed_name, preload: :component do |rule, _options|
      rule.displayed_name
    end
  end

  # === Viewer view: read-only detail (shared LEADING block) ===
  # Everything here appears at the same position for both kinds. Each subclass
  # re-opens :viewer to append its divergent tail — the :content_attributes
  # composition plus satisfies/satisfied_by (Rule) or derived_from_version /
  # rule_descriptions (authored).
  view :viewer do
    fields :rule_weight, :fixtext, :fixtext_fixref, :ident, :ident_system,
           :vendor_comments, :vuln_id, :legacy_ids,
           :component_id, :status_justification, :artifact_description,
           :locked_fields

    # Category 1: derives from the ident column, reaching nothing.
    field :nist_control_family do |rule, _options|
      rule.nist_control_family
    end

    # One kind-agnostic srg_id across document kinds: requirement lists read
    # rule.srg_id regardless of kind, and the model answers which value that is.
    # CATEGORY 1 here by default — an authored requirement holds the identifier
    # in its own version column. RuleBlueprint overrides this with
    # `preload: :srg_rule` (Category 3), reaching its source requirement, while
    # keeping the same output and position.
    field :srg_id do |rule, _options|
      rule.srg_identifier
    end
  end

  # === Shared content associations (internal composition target) ===
  # Never rendered on its own — each subclass's :viewer pulls it in with
  # `include_view :content_attributes` at the point its field order requires, so
  # the two identical `_attributes` associations are defined exactly once.
  # Category 3 by name, both — the `_attributes` keys match no model
  # association, so each names the real one.
  view :content_attributes do
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
  end
end
