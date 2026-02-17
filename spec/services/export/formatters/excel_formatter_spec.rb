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

  describe '#generate' do
    let(:headers) { ['Name', 'Status', 'Severity'] }
    let(:rows) { [['Rule 1', 'Applicable - Configurable', 'CAT II'], ['Rule 2', 'Not Applicable', 'CAT I']] }

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
      rows_with_nil = [['Rule 1', nil, 'CAT II']]
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
          headers: ['Name', 'Status'],
          rows: [['Rule 1', 'AC'], ['Rule 2', 'NA']]
        },
        {
          name: 'Component-B-V1R2-2',
          headers: ['Name', 'Status'],
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

      expect(workbook.sheet(0).row(1)).to eq ['Name', 'Status']
      expect(workbook.sheet(1).row(1)).to eq ['Name', 'Status']
    end

    it 'each sheet has correct data rows' do
      result = formatter.generate_workbook(sheets: sheets)
      workbook = read_xlsx(result)

      sheet0 = parse_data_rows(workbook, 0)
      expect(sheet0.size).to eq 2
      expect(sheet0.first['Name']).to eq 'Rule 1'

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

  private

  # Helper to read xlsx binary string with Roo
  def read_xlsx(binary_data)
    tmpfile = Tempfile.new(['test', '.xlsx'])
    tmpfile.binmode
    tmpfile.write(binary_data)
    tmpfile.close
    workbook = Roo::Spreadsheet.open(tmpfile.path)
    # Store tmpfile reference to prevent GC cleanup before we're done
    workbook.instance_variable_set(:@_tmpfile, tmpfile)
    workbook
  end

  # Roo parse(headers: true) returns header self-mapping as first element.
  # Drop it to get just data rows (matching export_helper_spec pattern).
  def parse_data_rows(workbook, sheet_index)
    workbook.sheet(sheet_index).parse(headers: true).drop(1)
  end
end
