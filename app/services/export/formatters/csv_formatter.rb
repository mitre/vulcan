# frozen_string_literal: true

require 'csv'

module Export
  module Formatters
    # Generates CSV output from headers and row data.
    class CsvFormatter < BaseFormatter
      def generate(headers:, rows:)
        ::CSV.generate(headers: true) do |csv|
          csv << headers
          rows.each { |row| csv << row }
        end
      end

      def content_type
        'text/csv'
      end

      def file_extension
        '.csv'
      end
    end
  end
end
