# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Accumulates the Analyzer's classified output. The Applier (Phase 2,
      # card .8) consumes this verbatim and depends on the contract below.
      #
      # Hard guarantees the applier relies on:
      # - resolution_log is Array<Hash{String=>String}> only — no symbols,
      #   no AR objects, no Time. The applier appends it byte-for-byte to
      #   component_sync_events.resolution_log_json. (F19)
      # - resolution_log capped at MAX_RESOLUTION_LOG_ENTRIES so a
      #   pathological merge can't DOS the apply path. (F16)
      # - FieldChange#resolution is one of RuleFieldDiffer::VALID_FIELD_RESOLUTIONS.
      # - Partition invariant: matched + only_ours == ours_count and
      #   matched + only_theirs == theirs_count. validate_partition_invariant!
      #   enforces this and raises with an actionable message on violation.
      class MergePlan
        MAX_RESOLUTION_LOG_ENTRIES = 10_000

        ENTITY_KEYS = %w[rules reviews satisfactions memberships].freeze

        class PartitionInvariantError < StandardError; end
        class ResolutionLogOverflowError < StandardError; end

        attr_reader :component_id, :strategy, :manifest

        def initialize(component_id:, strategy:, manifest:)
          @component_id = component_id
          @strategy = strategy
          @manifest = manifest

          @partitions = ENTITY_KEYS.index_with { { 'matched' => 0, 'only_ours' => 0, 'only_theirs' => 0 } }
          @field_changes = {}
          @resolution_log = []
        end

        def add_rule_partition(matched:, only_ours:, only_theirs:)
          record_partition('rules', matched, only_ours, only_theirs)
        end

        def add_review_partition(matched:, only_ours:, only_theirs:)
          record_partition('reviews', matched, only_ours, only_theirs)
        end

        def add_satisfaction_partition(matched:, only_ours:, only_theirs:)
          record_partition('satisfactions', matched, only_ours, only_theirs)
        end

        def add_membership_partition(matched:, only_ours:, only_theirs:)
          record_partition('memberships', matched, only_ours, only_theirs)
        end

        def add_field_changes(rule_id, changes)
          (@field_changes[rule_id] ||= []).concat(Array(changes))
        end

        def add_resolution_log_entry(entry:)
          raise ArgumentError, 'resolution_log entries must use string keys (F19)' unless entry.keys.all?(String)
          raise ArgumentError, 'resolution_log entries must use string values (F19)' unless entry.values.all?(String)

          if @resolution_log.size >= self.class::MAX_RESOLUTION_LOG_ENTRIES
            raise ResolutionLogOverflowError,
                  "resolution_log exceeded #{self.class::MAX_RESOLUTION_LOG_ENTRIES} entries (F16)"
          end

          @resolution_log << entry.dup.freeze
        end

        # Frozen snapshot — callers (rake formatter, applier) iterate but
        # never mutate.
        def resolution_log
          @resolution_log.dup.freeze
        end

        def summary
          @partitions.transform_values(&:dup)
        end

        def conflicts
          all_field_changes.select { |c| %i[conflict locked_conflict].include?(c.resolution) }
        end

        def auto_merged
          all_field_changes.select { |c| %i[auto_ours auto_theirs auto_merged].include?(c.resolution) }
        end

        def skipped
          all_field_changes.select { |c| c.resolution == :skip }
        end

        # Partition invariant: every input belongs to exactly one bucket.
        # If the side counts don't reconcile, the matcher (or downstream
        # transform) dropped or double-counted rows — surface immediately.
        def validate_partition_invariant!(entity, ours_count:, theirs_count:)
          key = entity.to_s
          p = @partitions.fetch(key)

          unless p['matched'] + p['only_ours'] == ours_count
            raise PartitionInvariantError,
                  "#{key}: matched (#{p['matched']}) + only_ours (#{p['only_ours']}) " \
                  "!= ours_count (#{ours_count})"
          end
          return if p['matched'] + p['only_theirs'] == theirs_count

          raise PartitionInvariantError,
                "#{key}: matched (#{p['matched']}) + only_theirs (#{p['only_theirs']}) " \
                "!= theirs_count (#{theirs_count})"
        end

        private

        def record_partition(entity_key, matched, only_ours, only_theirs)
          @partitions[entity_key] = {
            'matched' => Array(matched).size,
            'only_ours' => Array(only_ours).size,
            'only_theirs' => Array(only_theirs).size
          }
        end

        def all_field_changes
          @field_changes.values.flatten
        end
      end
    end
  end
end
