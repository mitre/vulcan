# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Per-entity / per-field resolution policy for the merge engine.
      # Resolutions are advisory: the analyzer consults Strategy when both
      # sides diverge on a field, and Strategy returns one of seven verbs.
      # Locked fields are non-negotiable — they always conflict.
      #
      # Per expert review F18, .from_cli_flags is intentionally NOT defined
      # here; CLI parsing belongs in the rake task layer (commit 10).
      class Strategy
        VALID_STRATEGY_RESOLUTIONS = %i[ours theirs newer conflict union skip manual].freeze

        # Defaults are tuned for the receiving instance:
        # - rule content fields default to :conflict because content drift
        #   from another instance should be reviewed, not silently overwritten
        # - memberships and satisfactions are set-like and default to :union
        # - review triage_status defaults to :ours because triage state is
        #   instance-local
        #
        # Note (v2-480.41): the merge engine only diffs/merges rule fields +
        # nested associations (checks, disa_rule_descriptions) + reviews +
        # satisfactions + memberships. Component-level metadata (comment_phase,
        # closed_reason, metadata, additional_questions, etc.) round-trips
        # via BackupSerializer but does NOT participate in merge resolution;
        # the receiving component's values are preserved as-is. No
        # DEFAULT_STRATEGY[:component] entry — anyone attempting to merge
        # component metadata should add a component_meta partition to
        # MergePlan/Analyzer/Applier first.
        DEFAULT_STRATEGY = {
          rule: {
            _default: :conflict,
            'check_content' => :conflict,
            'fixtext' => :conflict,
            'vuln_discussion' => :conflict,
            'title' => :conflict,
            'rule_severity' => :conflict
          },
          review: {
            _default: :skip,
            'triage_status' => :ours,
            'comment' => :skip
          },
          memberships: :union,
          satisfactions: :union
        }.freeze

        def initialize(overrides: {})
          @overrides = overrides.transform_values do |entity_overrides|
            entity_overrides.is_a?(Hash) ? entity_overrides.dup : entity_overrides
          end
          validate_resolutions!
        end

        # Returns the resolution verb for a given (entity, field) pair.
        # Falls through entity-level overrides, then defaults, finally the
        # entity's `_default` sentinel.
        def for_field(entity, field)
          entity_overrides = @overrides[entity] || {}
          entity_defaults = DEFAULT_STRATEGY[entity] || {}

          entity_overrides[field.to_s] ||
            entity_overrides[:_default] ||
            entity_defaults[field.to_s] ||
            entity_defaults[:_default] ||
            :conflict
        end

        # Returns the resolution verb for a whole-entity strategy
        # (memberships and satisfactions are set-like, not field-by-field).
        def for_entity(entity)
          @overrides[entity] || DEFAULT_STRATEGY[entity]
        end

        # Locked fields are non-negotiable — caller never gets to override
        # this. Returns :conflict by contract.
        def locked_field_resolution
          :conflict
        end

        private

        def validate_resolutions!
          @overrides.each_value do |entity_overrides|
            resolutions = entity_overrides.is_a?(Hash) ? entity_overrides.values : [entity_overrides]
            resolutions.each do |r|
              next if VALID_STRATEGY_RESOLUTIONS.include?(r)

              raise ArgumentError,
                    "unknown resolution: #{r.inspect} (valid: #{VALID_STRATEGY_RESOLUTIONS.inspect})"
            end
          end
        end
      end
    end
  end
end
