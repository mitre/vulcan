# frozen_string_literal: true

# BenchmarkCsvExport - DRY CSV export for STIG/SRG/Component models
#
# Provides configurable CSV export with:
# - Default columns from ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS
# - Column selection via columns: parameter
# - Header overrides (e.g., "STIG ID" → "SRG ID" for SRG context)
# - Automatic eager loading of disa_rule_descriptions and checks
# - Ordering by version, rule_id
#
# Including class must implement:
# - rules_association: returns the rules association to export
#
# Including class may optionally implement:
# - default_columns: returns array of column keys (overrides BENCHMARK_CSV_DEFAULT_COLUMNS)
# - header_overrides: returns hash of column key => custom header (e.g., { version: 'SRG ID' })
module BenchmarkCsvExport
  extend ActiveSupport::Concern

  # Generate CSV export with configurable columns
  #
  # @param columns [Array<Symbol>] Column keys to include (defaults to default_columns or BENCHMARK_CSV_DEFAULT_COLUMNS)
  # @param header_overrides [Hash<Symbol, String>] Custom headers for specific columns
  # @return [String] CSV string with headers and data rows
  def csv_export(columns: nil, header_overrides: {})
    columns ||= respond_to?(:default_columns) ? default_columns : ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS
    overrides = respond_to?(:header_overrides) ? self.header_overrides.merge(header_overrides) : header_overrides
    headers = columns.map { |key| overrides[key] || ExportConstants::BENCHMARK_CSV_COLUMNS[key][:header] }

    ::CSV.generate(headers: true) do |csv|
      csv << headers
      rules_association.eager_load(:disa_rule_descriptions, :checks)
                       .order(:version, :rule_id)
                       .each do |rule|
        csv << columns.map { |key| rule.csv_value_for(key) }
      end
    end
  end
end
