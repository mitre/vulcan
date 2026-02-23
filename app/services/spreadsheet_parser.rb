# frozen_string_literal: true

# Shared spreadsheet parsing and validation for Component import operations.
# Used by both Component#from_spreadsheet (create) and Component#update_from_spreadsheet (update).
class SpreadsheetParser
  include ImportConstants

  attr_reader :errors

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
    return parsed if parsed.empty?

    file_headers = parsed.first.keys
    rename_map = {}
    HEADER_ALIASES.each do |export_header, import_header|
      rename_map[export_header] = import_header if file_headers.include?(export_header)
    end

    return parsed if rename_map.empty?

    parsed.map do |row|
      row.transform_keys { |key| rename_map[key] || key }
    end
  end

  def error_result(message)
    { error: message }
  end
end
