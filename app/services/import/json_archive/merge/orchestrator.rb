# frozen_string_literal: true

require 'tempfile'

module Import
  module JsonArchive
    module Merge
      # Phase 2c coordinator. Wraps parse → analyze → apply for a single
      # inbound merge so the MergeJob (and controller endpoints) have one
      # callsite that returns a MergeResult regardless of where the
      # pipeline stops.
      #
      # PreconditionError raised by the Analyzer is captured into a failed
      # MergeResult with structured_error step: :analyze rather than
      # bubbling out — the calling MergeJob persists the result for the
      # operator to triage, and exceptions would erase that audit trail.
      # Apply-side failures stay inside the Applier's existing rescue
      # ladder; this class never re-raises from #call.
      class Orchestrator
        # @param archive_bytes [String] raw zip bytes (e.g. from a Tempfile
        #   uploaded via the controller). Required — nil/blank fails fast.
        # @param component [Component] the receiving component
        # @param actor [User, nil] who authorized the merge (forwarded to
        #   Applier so per-record audit rows get who-authorized attribution)
        # @param strategy_overrides [Hash, nil] forwarded to
        #   Strategy.new(overrides:); see Strategy::DEFAULT_STRATEGY
        # @param manifest [Hash, nil] explicit manifest override; defaults
        #   to the one parsed from archive_bytes
        # @param source [String] one of Applier::VALID_SOURCES; default
        #   'theirs' (the inbound MergeJob path).
        def initialize(archive_bytes:, component:, actor:, strategy_overrides: nil,
                       manifest: nil, source: 'theirs')
          @archive_bytes = archive_bytes
          @component = component
          @actor = actor
          @strategy_overrides = strategy_overrides
          @manifest_override = manifest
          @source = source
        end

        # Returns a MergeResult. Never raises; failures are captured as
        # structured errors keyed by the step that owned the failure.
        def call
          merge_input = parse_archive_bytes
          return @failed_result if @failed_result

          manifest = @manifest_override || merge_input.manifest

          begin
            SignatureGate.verify!(manifest)
          rescue SignatureGate::MissingSignatureError => e
            return failed_result_with_step(:signature, e.message)
          end

          strategy = Strategy.new(overrides: @strategy_overrides || {})

          begin
            plan = Analyzer.new(
              merge_input: merge_input, component: @component,
              strategy: strategy, manifest: manifest
            ).call
          rescue PreconditionError => e
            return failed_result_with_step(:analyze, e.message)
          end

          Applier.new(
            merge_plan: plan, component: @component, source: @source,
            archive_bytes: @archive_bytes, actor: @actor
          ).call
        end

        private

        # Bytes → Tempfile → MergeInput.from_zip_path. The tempfile is
        # auto-unlinked when the block returns; on parse failure we
        # capture into @failed_result so #call returns a MergeResult.
        def parse_archive_bytes
          if @archive_bytes.blank?
            @failed_result = failed_result_with_step(:parse, 'archive_bytes is required and must not be blank')
            return nil
          end

          tempfile = Tempfile.new(['merge_orchestrator', '.zip'])
          tempfile.binmode
          tempfile.write(@archive_bytes)
          tempfile.flush
          MergeInput.from_zip_path(tempfile.path)
        rescue ArgumentError, Zip::Error, JSON::ParserError => e
          @failed_result = failed_result_with_step(:parse, "#{e.class.name}: #{e.message}")
          nil
        ensure
          tempfile&.close
          tempfile&.unlink
        end

        def failed_result_with_step(step, message)
          result = MergeResult.new
          result.add_structured_error(
            entity_type: :component,
            entity_key: @component&.id.to_s,
            step: step,
            message: message
          )
          result
        end
      end
    end
  end
end
