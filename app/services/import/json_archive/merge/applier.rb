# frozen_string_literal: true

require 'securerandom'
require 'digest'

module Import
  module JsonArchive
    module Merge
      # Phase 2 write-side counterpart to Analyzer. Takes a resolved
      # MergePlan and applies it to the database under a serializable
      # transaction with a pre-merge snapshot, capturing every write to
      # merge_operations + a ComponentSyncEvent row for auditability.
      #
      # Phase 1 commit (skeleton): the lifecycle + sync event + transaction
      # wrapper land here. Per-entity apply logic (rules, reviews,
      # satisfactions, memberships) lands in subsequent commits.
      class Applier
        TRANSACTION_ISOLATION = :serializable
        VALID_SOURCES = %w[theirs ours auto_merge].freeze

        attr_reader :sync_event

        # @param merge_plan [MergePlan] from Analyzer#call
        # @param component [Component] the receiving component (live AR)
        # @param source [String] one of VALID_SOURCES — labels the
        #   ComponentSyncEvent's source field
        # @param archive_bytes [String, nil] raw zip bytes for SHA-256
        #   hashing (commit 2 wires this in for replay protection)
        def initialize(merge_plan:, component:, source:, archive_bytes: nil)
          @merge_plan = merge_plan
          @component = component
          @source = source
          @archive_bytes = archive_bytes
          @result = MergeResult.new
        end

        def call
          @sync_event = create_sync_event
          @result.attach_plan(@merge_plan)

          begin
            validate_apply_preconditions!
            take_pre_merge_snapshot!
            with_serializable_transaction { apply_all }
            mark_event_status('applied')
          rescue PreconditionError => e
            mark_event_status('failed')
            @result.add_structured_error(
              entity_type: :component, entity_key: @component.id.to_s,
              step: :precondition, message: e.message
            )
          rescue ActiveRecord::SerializationFailure
            mark_event_status('failed')
            @result.add_structured_error(
              entity_type: :component, entity_key: @component.id.to_s,
              step: :apply, message: 'component modified during merge (serialization conflict)'
            )
          rescue StandardError => e
            mark_event_status('failed')
            @result.add_structured_error(
              entity_type: :component, entity_key: @component.id.to_s,
              step: :apply, message: "#{e.class.name}: #{e.message}"
            )
          end

          @result
        end

        private

        # Per-entity apply pipeline. Each method is a no-op in commit 1
        # (skeleton) and gets filled in by subsequent commits.
        def apply_all
          # rules, reviews, satisfactions, memberships land in commits 3-8
        end

        def create_sync_event
          ComponentSyncEvent.create!(
            component: @component,
            sync_id: SecureRandom.uuid,
            source: @source,
            direction: 'inbound',
            status: 'pending',
            resolution_log_json: @merge_plan.resolution_log,
            archive_hash: @archive_bytes && Digest::SHA256.hexdigest(@archive_bytes)
          )
        end

        # The apply path requires concurrent-edit protection — the
        # receiving component must be in 'closed' comment_phase so no one
        # is mid-write while we apply theirs. Analyzer (read-only) does
        # not require this. Raises PreconditionError on failure
        # so the same exception class is used uniformly across the
        # analyze + apply boundary.
        def validate_apply_preconditions!
          return if @component.comment_phase == Analyzer::COMMENT_PHASE_REQUIRED

          raise PreconditionError,
                "component.comment_phase must be '#{Analyzer::COMMENT_PHASE_REQUIRED}' to apply " \
                "(got '#{@component.comment_phase}')"
        end

        # Captures the current state of the receiving component as a
        # zip + checksum so disaster-recovery (v2-480.10) can restore it
        # if a merge is reverted. Snapshot path recorded on the sync event.
        def take_pre_merge_snapshot!
          path = SnapshotManager.create_snapshot(@component)
          @sync_event.update!(snapshot_path: path)
        end

        # When the applier is invoked outside an existing transaction (the
        # production controller / rake path), request serializable
        # isolation explicitly so concurrent writers are caught via
        # SerializationFailure. When already inside a transaction (test
        # fixtures, or a caller that already opened one), join it — PG
        # only allows isolation to be set on the outermost transaction.
        def with_serializable_transaction(&)
          if ActiveRecord::Base.connection.transaction_open?
            ActiveRecord::Base.transaction(&)
          else
            ActiveRecord::Base.transaction(isolation: TRANSACTION_ISOLATION, &)
          end
        end

        def mark_event_status(status)
          return if @sync_event.nil?

          @sync_event.update!(status: status)
        end
      end
    end
  end
end
