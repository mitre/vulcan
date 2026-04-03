# frozen_string_literal: true

# Shared spreadsheet parsing and validation for Component import operations.
# Used by both Component#from_spreadsheet (create) and Component#update_from_spreadsheet (update).
class SpreadsheetParser
  include ImportConstants

  attr_reader :errors

  # Lightweight class method: peek at the SRGID column without full validation.
  # Returns an array of unique, non-blank SRG ID strings found in the file.
  # Returns [] on any error (missing column, parse failure, empty file).
  #
  # @param spreadsheet [String, ActionDispatch::Http::UploadedFile] path or uploaded file
  # @return [Array<String>]
  # Normalize aliased export headers back to import header names.
  # Shared by peek_srg_ids and instance normalize_headers.
  #
  # @param rows [Array<Hash>] parsed spreadsheet rows with header keys
  # @return [Array<Hash>] rows with aliased headers renamed
  def self.normalize_header_aliases(rows)
    return rows if rows.empty?

    file_headers = rows.first.keys
    rename_map = {}
    ImportConstants::HEADER_ALIASES.each do |export_header, import_header|
      rename_map[export_header] = import_header if file_headers.include?(export_header)
    end

    return rows if rename_map.empty?

    rows.map { |row| row.transform_keys { |key| rename_map[key] || key } }
  end

  def self.peek_srg_ids(spreadsheet)
    rows = Roo::Spreadsheet.open(spreadsheet).sheet(0).parse(headers: true).drop(1)
    return [] if rows.empty?

    rows = normalize_header_aliases(rows)

    srg_id_col = ImportConstants::IMPORT_MAPPING[:srg_id] # "SRGID"
    return [] unless rows.first.key?(srg_id_col)

    rows.pluck(srg_id_col).compact_blank.uniq
  rescue StandardError
    []
  end

  # @param spreadsheet [String, ActionDispatch::Http::UploadedFile] path or uploaded file
  # @param srg_id [Integer] SecurityRequirementsGuide ID to validate against
  def initialize(spreadsheet, srg_id)
    @spreadsheet = spreadsheet
    @srg_id = srg_id
    @errors = []
  end

  # Parse spreadsheet, normalize headers, validate headers and SRG IDs.
  # Returns { rows:, srg_rules:, file_headers: } on success, or { error: } on failure.
  def parse_and_validate
    parsed = open_spreadsheet
    return error_result(@errors.first) unless @errors.empty?

    parsed = normalize_headers(parsed)
    return error_result('Spreadsheet is empty') if parsed.empty?

    file_headers = parsed.first.keys

    missing_headers = REQUIRED_MAPPING_CONSTANTS.values - file_headers
    return error_result("Missing required headers: #{missing_headers.join(', ')}") unless missing_headers.empty?

    srg_rules = SecurityRequirementsGuide.find(@srg_id).srg_rules
    database_srg_ids = srg_rules.map(&:version)
    spreadsheet_srg_ids = parsed.pluck(IMPORT_MAPPING[:srg_id]).compact_blank
    missing_from_srg = spreadsheet_srg_ids - database_srg_ids

    unless missing_from_srg.empty?
      return error_result(
        "SRG IDs not found in selected SRG: #{missing_from_srg.join(', ')}"
      )
    end

    { rows: parsed, srg_rules: srg_rules, file_headers: file_headers }
  end

  private

  def open_spreadsheet
    Roo::Spreadsheet.open(@spreadsheet).sheet(0).parse(headers: true).drop(1)
  rescue StandardError => e
    @errors << "Failed to parse spreadsheet: #{e.message}"
    []
  end

  def normalize_headers(parsed)
    self.class.normalize_header_aliases(parsed)
  end

  def error_result(message)
    { error: message }
  end
end
