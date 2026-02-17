# frozen_string_literal: true

module Export
  module Formatters
    # Abstract base for export formatters. Formatters serialize data into
    # a specific file format (CSV, Excel, XCCDF, InSpec).
    #
    # Two pipelines:
    # 1. Row-based (CSV, Excel): generate(headers:, rows:) — flat tabular data
    # 2. Component-based (XCCDF, InSpec): generate_from_component(component:, rules:)
    #    — rich objects, formatter builds structured output
    class BaseFormatter
      def generate(headers:, rows:)
        raise NotImplementedError
      end

      # Multi-sheet formatters (Excel) override this to aggregate all components
      # into a single workbook instead of producing separate files per component.
      def multi_sheet?
        false
      end

      # Override in multi-sheet formatters. Each sheet: { name:, headers:, rows: }.
      def generate_workbook(sheets:)
        raise NotImplementedError
      end

      # Component-based formatters (XCCDF, InSpec) receive full component + rules
      # instead of flat rows. Override to return serialized data (XML string, zip buffer).
      def component_based?
        false
      end

      def generate_from_component(component:, rules:)
        raise NotImplementedError
      end

      # Batch formatters (InSpec) receive all components at once to produce
      # a single archive with subdirectories. Override batch_generate? and generate_batch.
      def batch_generate?
        false
      end

      def generate_batch(component_rule_pairs:)
        raise NotImplementedError
      end

      def content_type
        raise NotImplementedError
      end

      def file_extension
        raise NotImplementedError
      end
    end
  end
end
