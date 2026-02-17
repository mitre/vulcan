# frozen_string_literal: true

module Export
  module Formatters
    # Abstract base for export formatters. Formatters serialize data into
    # a specific file format (CSV, Excel, XCCDF, InSpec).
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

      def content_type
        raise NotImplementedError
      end

      def file_extension
        raise NotImplementedError
      end
    end
  end
end
