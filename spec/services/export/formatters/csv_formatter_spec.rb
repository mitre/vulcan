# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: CsvFormatter takes headers + rows from a mode and generates
# a valid CSV string with correct headers and data rows.
# ==========================================================================
RSpec.describe Export::Formatters::CsvFormatter do
  subject(:formatter) { described_class.new }

  describe '#generate' do
    let(:headers) { ['Name', 'Status', 'Severity'] }
    let(:rows) { [['Rule 1', 'Applicable - Configurable', 'CAT II'], ['Rule 2', 'Not Applicable', 'CAT I']] }

    it 'returns a CSV string' do
      result = formatter.generate(headers: headers, rows: rows)
      expect(result).to be_a(String)
    end

    it 'includes headers as first row' do
      result = formatter.generate(headers: headers, rows: rows)
      parsed = CSV.parse(result)
      expect(parsed.first).to eq headers
    end

    it 'includes all data rows' do
      result = formatter.generate(headers: headers, rows: rows)
      parsed = CSV.parse(result)
      expect(parsed.size).to eq 3 # 1 header + 2 data
      expect(parsed[1]).to eq rows[0]
      expect(parsed[2]).to eq rows[1]
    end

    it 'handles nil values in rows' do
      rows_with_nil = [['Rule 1', nil, 'CAT II']]
      result = formatter.generate(headers: headers, rows: rows_with_nil)
      parsed = CSV.parse(result)
      expect(parsed[1][1]).to be_nil
    end

    it 'handles empty rows array' do
      result = formatter.generate(headers: headers, rows: [])
      parsed = CSV.parse(result)
      expect(parsed.size).to eq 1 # headers only
    end
  end

  describe '#content_type' do
    it 'returns text/csv' do
      expect(formatter.content_type).to eq 'text/csv'
    end
  end

  describe '#file_extension' do
    it 'returns .csv' do
      expect(formatter.file_extension).to eq '.csv'
    end
  end
end
