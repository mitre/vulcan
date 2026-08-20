# frozen_string_literal: true

# Serializes STIG Rule records. Inherits the shared requirement surface from
# BaseRuleBlueprint (identifier, default fields, comment_summary, navigator,
# picker head, viewer head + srg_id, and the :content_attributes composition)
# and adds the Rule-only surface: the satisfaction graph, inspec content, the
# source SRG requirement, additional answers, and reviews/histories.
#
# Replaces Rule#as_json and BaseRule#as_json overrides.
#
# Views:
#   :navigator — sidebar rule list (inherited; minimal fields for sort/filter)
#   :picker    — RulePicker dropdown (inherited head + satisfaction IDs)
#   :viewer    — read-only detail (srg_id preload + content attrs + satisfactions)
#   :editor    — full editing form (adds reviews, SRG data, satisfactions)
#
# PRELOAD DECLARATIONS — every block-bearing entry states its category; see
# BaseRuleBlueprint for the full scheme.
class RuleBlueprint < BaseRuleBlueprint
  # === Picker view: satisfaction relationship IDs for parent/child badges ===
  # Appends to the inherited head (displayed_name). No text blobs, no reviews.
  view :picker do
    # Category 2, both.
    association :satisfies, blueprint: SatisfactionBlueprint do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.satisfies)
    end

    association :satisfied_by, blueprint: SatisfactionBlueprint do |rule, _options|
      ApplicationRecord.sorted_by_id(rule.satisfied_by)
    end
  end

  # === Viewer view: srg_id preload + shared content attrs + satisfactions ===
  view :viewer do
    # Category 3: a Rule answers for its SRG identifier by reaching its source
    # requirement, unlike an authored requirement which holds the value itself.
    # Overrides the base srg_id (Category 1) in place — same output, same
    # position, now batched. See BaseRuleBlueprint#srg_id.
    field :srg_id, preload: :srg_rule do |rule, _options|
      rule.srg_identifier
    end

    include_view :content_attributes

    # Category 2, both.
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
    # whole collection. The per-requirement endpoint asks for it; the collection
    # does not. (Category 0.)
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
