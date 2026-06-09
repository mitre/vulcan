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

        # v2-480.39 — single source of truth for verb → {resolution, source}.
        # RuleFieldDiffer / NestedAssociationDiffer consult :resolution to
        # build FieldChange; Applier consults :source to stamp MergeOperation.
        # Verbs not in this map are programmer errors (Strategy validates
        # overrides at construction). :newer/:manual map to :conflict —
        # Phase 1 does not auto-merge those; the operator must reconcile.
        VERB_TRANSLATION = {
          ours: { resolution: :auto_ours, source: 'ours' }.freeze,
          theirs: { resolution: :auto_theirs, source: 'theirs' }.freeze,
          skip: { resolution: :auto_ours, source: 'ours' }.freeze,
          union: { resolution: :auto_merged, source: 'auto_merge' }.freeze,
          conflict: { resolution: :conflict, source: 'conflict_resolved' }.freeze,
          newer: { resolution: :conflict, source: 'conflict_resolved' }.freeze,
          manual: { resolution: :conflict, source: 'conflict_resolved' }.freeze
        }.freeze

        # Centralized verb → {resolution:, source:} lookup. Returns nil
        # when verb is not in the canonical map (callers fall back to
        # :conflict — matches the legacy fallthrough but is now explicit).
        def self.resolve_verb(verb)
          VERB_TRANSLATION[verb]
        end

        # Scalar entities — :union is only valid for set-like entities
        # (memberships, satisfactions). validate_resolutions! enforces.
        SCALAR_FIELD_ENTITIES = %i[rule review].freeze
        private_constant :SCALAR_FIELD_ENTITIES

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
          @overrides.each do |entity, entity_overrides|
            if entity_overrides.is_a?(Hash)
              entity_overrides.each_value { |r| validate_field_resolution!(entity, r) }
            else
              validate_entity_resolution!(entity_overrides)
            end
          end
        end

        def validate_field_resolution!(entity, resolution)
          unless VALID_STRATEGY_RESOLUTIONS.include?(resolution)
            raise ArgumentError,
                  "unknown resolution: #{resolution.inspect} (valid: #{VALID_STRATEGY_RESOLUTIONS.inspect})"
          end
          return unless resolution == :union && SCALAR_FIELD_ENTITIES.include?(entity)

          raise ArgumentError,
                ":union is not valid for scalar #{entity} fields — only set-like entities " \
                '(memberships, satisfactions) accept :union'
        end

        def validate_entity_resolution!(resolution)
          return if VALID_STRATEGY_RESOLUTIONS.include?(resolution)

          raise ArgumentError,
                "unknown resolution: #{resolution.inspect} (valid: #{VALID_STRATEGY_RESOLUTIONS.inspect})"
        end
      end
    end
  end
end
