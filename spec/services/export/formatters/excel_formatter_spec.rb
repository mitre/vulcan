# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: ExcelFormatter generates multi-sheet Excel workbooks using
# FastExcel. Each component becomes one worksheet. The output is a valid
# .xlsx binary string.
#
# Key behaviors:
# - generate(headers:, rows:) produces a single-sheet workbook
# - generate_workbook(sheets:) produces a multi-sheet workbook
# - multi_sheet? returns true (tells Base to aggregate before formatting)
# - Worksheet names match FileNamer conventions
#
# NOTE: Roo's parse(headers: true) returns the header row as the first
# element (self-mapping hash), then data rows. Use .drop(1) for data only.
# ==========================================================================
RSpec.describe Export::Formatters::ExcelFormatter do
  subject(:formatter) { described_class.new }

  let(:rule_1_name) { 'Rule 1' }

  describe '#generate' do
    let(:headers) { %w[Name Status Severity] }
    let(:rows) { [[rule_1_name, 'Applicable - Configurable', 'CAT II'], ['Rule 2', 'Not Applicable', 'CAT I']] }

    it 'returns a binary string' do
      result = formatter.generate(headers: headers, rows: rows)
      expect(result).to be_a(String)
    end

    it 'produces a valid xlsx (starts with PK zip magic bytes)' do
      result = formatter.generate(headers: headers, rows: rows)
      expect(result.bytes[0..1]).to eq [0x50, 0x4B]
    end

    it 'produces a workbook with one sheet' do
      result = formatter.generate(headers: headers, rows: rows)
      workbook = read_xlsx(result)
      expect(workbook.sheets.size).to eq 1
    end

    it 'sheet contains correct headers' do
      result = formatter.generate(headers: headers, rows: rows)
      workbook = read_xlsx(result)
      # Row 1 is the header row (Roo is 1-indexed)
      expect(workbook.sheet(0).row(1)).to eq headers
    end

    it 'sheet contains correct number of data rows' do
      result = formatter.generate(headers: headers, rows: rows)
      workbook = read_xlsx(result)
      data_rows = parse_data_rows(workbook, 0)
      expect(data_rows.size).to eq rows.size
    end

    it 'handles nil values in rows' do
      rows_with_nil = [[rule_1_name, nil, 'CAT II']]
      result = formatter.generate(headers: headers, rows: rows_with_nil)
      workbook = read_xlsx(result)
      data_rows = parse_data_rows(workbook, 0)
      expect(data_rows.first['Status']).to be_nil
    end

    it 'handles empty rows array' do
      result = formatter.generate(headers: headers, rows: [])
      workbook = read_xlsx(result)
      data_rows = parse_data_rows(workbook, 0)
      expect(data_rows.size).to eq 0
    end
  end

  describe '#generate_workbook' do
    let(:sheets) do
      [
        {
          name: 'Component-A-V1R1-1',
          headers: %w[Name Status],
          rows: [[rule_1_name, 'AC'], ['Rule 2', 'NA']]
        },
        {
          name: 'Component-B-V1R2-2',
          headers: %w[Name Status],
          rows: [['Rule 3', 'AIM']]
        }
      ]
    end

    it 'returns a binary string' do
      result = formatter.generate_workbook(sheets: sheets)
      expect(result).to be_a(String)
    end

    it 'produces a valid xlsx' do
      result = formatter.generate_workbook(sheets: sheets)
      expect(result.bytes[0..1]).to eq [0x50, 0x4B]
    end

    it 'creates one worksheet per sheet entry' do
      result = formatter.generate_workbook(sheets: sheets)
      workbook = read_xlsx(result)
      expect(workbook.sheets.size).to eq 2
    end

    it 'names worksheets correctly' do
      result = formatter.generate_workbook(sheets: sheets)
      workbook = read_xlsx(result)
      expect(workbook.sheets).to eq ['Component-A-V1R1-1', 'Component-B-V1R2-2']
    end

    it 'each sheet has correct headers' do
      result = formatter.generate_workbook(sheets: sheets)
      workbook = read_xlsx(result)

      expect(workbook.sheet(0).row(1)).to eq %w[Name Status]
      expect(workbook.sheet(1).row(1)).to eq %w[Name Status]
    end

    it 'each sheet has correct data rows' do
      result = formatter.generate_workbook(sheets: sheets)
      workbook = read_xlsx(result)

      sheet0 = parse_data_rows(workbook, 0)
      expect(sheet0.size).to eq 2
      expect(sheet0.first['Name']).to eq rule_1_name

      sheet1 = parse_data_rows(workbook, 1)
      expect(sheet1.size).to eq 1
      expect(sheet1.first['Name']).to eq 'Rule 3'
    end

    it 'handles a single sheet' do
      single = [sheets.first]
      result = formatter.generate_workbook(sheets: single)
      workbook = read_xlsx(result)
      expect(workbook.sheets.size).to eq 1
    end

    it 'handles sheets with empty rows' do
      empty_sheet = [{ name: 'Empty', headers: ['Col'], rows: [] }]
      result = formatter.generate_workbook(sheets: empty_sheet)
      workbook = read_xlsx(result)
      data_rows = parse_data_rows(workbook, 0)
      expect(data_rows.size).to eq 0
    end
  end

  describe '#multi_sheet?' do
    it 'returns true' do
      expect(formatter.multi_sheet?).to be true
    end
  end

  describe '#content_type' do
    it 'returns Excel MIME type' do
      expect(formatter.content_type).to eq 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end
  end

  describe '#file_extension' do
    it 'returns .xlsx' do
      expect(formatter.file_extension).to eq '.xlsx'
    end
  end

  # ===========================================================================
  # REQUIREMENT: When rows contain a "Source" column, the formatter must:
  # - Apply grey background to inherited rows (Source = "Inherited")
  # - Lock inherited row cells so they can't be edited
  # - Add data validation dropdowns for Status, Severity, and Source columns
  # - Enable sheet protection (allows filter/sort, enforces cell locks)
  # - Add auto-filter on the header row
  # ===========================================================================
  describe 'inherited row styling and data validation' do
    let(:headers) { %w[STIGID Status Check Fix Severity Source] }
    let(:direct_row) { ['TEST-001', 'Applicable - Configurable', 'check text', 'fix text', 'CAT II', 'Direct'] }
    let(:inherited_row) { ['TEST-002', 'Applicable - Configurable', 'inherited check', 'inherited fix', 'CAT II', 'Inherited'] }
    let(:rows) { [direct_row, inherited_row] }

    let(:result) { formatter.generate(headers: headers, rows: rows) }
    let(:workbook) { read_xlsx(result) }

    it 'includes all rows in the output' do
      data_rows = parse_data_rows(workbook, 0)
      expect(data_rows.size).to eq 2
    end

    it 'preserves Source column values' do
      data_rows = parse_data_rows(workbook, 0)
      expect(data_rows[0]['Source']).to eq 'Direct'
      expect(data_rows[1]['Source']).to eq 'Inherited'
    end

    # Test XLSX internals by reading the zip XML directly
    describe 'xlsx structure' do
      let(:xlsx_xml) do
        entries = {}
        Zip::File.open_buffer(StringIO.new(result)) do |zip|
          zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
        end
        entries
      end

      it 'includes sheet protection' do
        sheet_xml = xlsx_xml.values.find { |v| v.include?('<sheetData') }
        expect(sheet_xml).to include('sheetProtection')
      end

      it 'includes data validations' do
        sheet_xml = xlsx_xml.values.find { |v| v.include?('<sheetData') }
        expect(sheet_xml).to include('dataValidation')
      end

      it 'includes autoFilter on the header row' do
        sheet_xml = xlsx_xml.values.find { |v| v.include?('<sheetData') }
        expect(sheet_xml).to include('autoFilter')
      end
    end
  end
end
