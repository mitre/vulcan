# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Outcome wrapper for merge operations (Phase 1 Analyzer surfaces it
      # through the rake task and Phase 2 Applier through the controller).
      # Extends Import::Result with structured errors so the caller can
      # tell *what* failed and *where*, not just receive a flat string.
      class MergeResult < Import::Result
        StructuredError = Struct.new(:entity_type, :entity_key, :step, :message, keyword_init: true) do
          def to_h
            { 'entity_type' => entity_type.to_s, 'entity_key' => entity_key.to_s,
              'step' => step.to_s, 'message' => message.to_s }
          end
        end

        attr_reader :plan

        def initialize
          super
          @structured_errors = []
        end

        def attach_plan(plan)
          @plan = plan
          merge_summary(plan.summary)
        end

        # @param entity_type [Symbol] e.g. :rule, :review, :satisfaction
        # @param entity_key [String, Integer] rule_id / external_id / etc.
        # @param step [Symbol] e.g. :match, :diff, :apply
        # @param message [String]
        def add_structured_error(entity_type:, entity_key:, step:, message:)
          err = StructuredError.new(
            entity_type: entity_type, entity_key: entity_key, step: step, message: message
          )
          @structured_errors << err
          add_error(format_message(err))
        end

        def structured_errors
          @structured_errors.dup.freeze
        end

        private

        def format_message(err)
          "[#{err.entity_type}/#{err.entity_key} @ #{err.step}] #{err.message}"
        end
      end
    end
  end
end
