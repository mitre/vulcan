# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Diffs a single live Rule against a normalized hash from the
      # incoming archive, field by field, using HASH COMPARISON (not
      # ActiveRecord Dirty).
      #
      # Per expert review F14, assign_attributes fires before_validation
      # callbacks (clear_stale_foreign_keys et al.) which mutate fields
      # during the diff and produce false positives. We compare raw
      # attribute values directly so the AR instance is never touched.
      #
      # Iteration is over Rule::MERGEABLE_FIELDS only — identity, lifecycle,
      # and derived columns (inspec_control_file) are excluded.
      class RuleFieldDiffer
        VALID_FIELD_RESOLUTIONS = %i[auto_ours auto_theirs auto_merged conflict locked_conflict].freeze

        # Map Strategy's seven verbs onto the five field-level outcomes.
        # :newer requires per-row timestamps — at rule-field grain we don't
        # have those, so fall through to :conflict to force review.
        # :skip behaves as :auto_ours (keep our value, drop theirs).
        # Unmapped verbs (:newer, :manual, :conflict, unknowns) collapse
        # to :conflict so a human has to weigh in.
        STRATEGY_VERB_MAP = {
          ours: :auto_ours,
          theirs: :auto_theirs,
          skip: :auto_ours,
          union: :auto_merged
        }.freeze

        # target_association: nil (top-level rule field) | :checks |
        #   :disa_rule_descriptions — routes Applier#apply_one_rule_change
        # target_identity: nil (positional pair) | {column => value} —
        #   resolves which nested record to update when N exist per rule
        FieldChange = Struct.new(
          :field, :from, :to, :resolution, :reason, :locked,
          :target_association, :target_identity,
          keyword_init: true
        )

        # @param ours_rule [Rule] the live AR rule (read-only here)
        # @param theirs_rule_hash [Hash] string-keyed snapshot from the archive
        # @param strategy [Strategy]
        # @param srg_baseline [Hash, nil] optional 3-way baseline (commit 7
        #   wires this in via RuleThreeWay; nil here = pure 2-way)
        def initialize(ours_rule:, theirs_rule_hash:, strategy:, srg_baseline: nil)
          @ours_rule = ours_rule
          @theirs_rule_hash = theirs_rule_hash
          @strategy = strategy
          @srg_baseline = srg_baseline
          @ours_attrs = ours_rule.attributes
          # locked_fields on Rule is a JSONB hash keyed by SECTION name
          # (e.g. {"Check" => true, "Fix" => true}), NOT a flat list of
          # column names. Locking a section locks every column that
          # RuleConstants::SECTION_FIELDS maps under it.
          @locked_sections = (ours_rule.locked_fields || {}).keys.to_set
        end

        def diff
          Rule::MERGEABLE_FIELDS.filter_map do |field|
            ours_val = @ours_attrs[field]
            theirs_val = @theirs_rule_hash[field]
            next if values_equal?(ours_val, theirs_val)

            build_change(field, ours_val, theirs_val)
          end
        end

        private

        # Hash comparison only — never assign_attributes. Treat nil and ''
        # as equal for string fields so empty-vs-missing doesn't false-fire.
        def values_equal?(ours, theirs)
          return true if ours == theirs
          return true if ours.nil? && theirs.respond_to?(:empty?) && theirs.empty?
          return true if theirs.nil? && ours.respond_to?(:empty?) && ours.empty?

          false
        end

        def build_change(field, ours_val, theirs_val)
          if field_locked?(field)
            FieldChange.new(
              field: field, from: ours_val, to: theirs_val,
              resolution: :locked_conflict, locked: true,
              reason: "Field '#{field}' is locked (section '#{RuleConstants::FIELD_TO_SECTION[field.to_sym]}') on the receiving component"
            )
          else
            verb = @strategy.for_field(:rule, field)
            FieldChange.new(
              field: field, from: ours_val, to: theirs_val,
              resolution: map_strategy_verb(verb),
              locked: false, reason: strategy_reason(verb)
            )
          end
        end

        def map_strategy_verb(verb)
          STRATEGY_VERB_MAP.fetch(verb, :conflict)
        end

        # A field is locked when its parent section is present in the
        # receiving component's locked_fields. RuleConstants::FIELD_TO_SECTION
        # is the canonical column→section map (e.g. :fixtext → 'Fix',
        # :check_content → 'Check'). Fields outside the map cannot be
        # locked, so default to false.
        def field_locked?(field)
          section = RuleConstants::FIELD_TO_SECTION[field.to_sym]
          return false unless section

          @locked_sections.include?(section)
        end

        def strategy_reason(verb)
          "Strategy resolved to #{verb.inspect}"
        end
      end
    end
  end
end
