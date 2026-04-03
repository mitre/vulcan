# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: Packager handles single vs multi-component export.
# Single component = passthrough (direct file data).
# Multiple components = zip file with one entry per component.
# ==========================================================================
RSpec.describe Export::Packager do
  let(:comp1_filename) { 'comp1.csv' }
  let(:comp2_filename) { 'comp2.csv' }
  let(:csv_content_type) { 'text/csv' }
  let(:export_zip) { 'export.zip' }

  describe '.package' do
    context 'with single result' do
      let(:results) do
        [Export::Result.new(data: 'csv-data-here', filename: comp1_filename, content_type: csv_content_type)]
      end

      it 'returns the single result directly (passthrough)' do
        packaged = described_class.package(results)
        expect(packaged.data).to eq 'csv-data-here'
        expect(packaged.filename).to eq comp1_filename
        expect(packaged.content_type).to eq csv_content_type
      end
    end

    context 'with multiple results' do
      let(:results) do
        [
          Export::Result.new(data: 'csv-data-1', filename: comp1_filename, content_type: csv_content_type),
          Export::Result.new(data: 'csv-data-2', filename: comp2_filename, content_type: csv_content_type)
        ]
      end

      it 'returns a zip file' do
        packaged = described_class.package(results, zip_filename: export_zip)
        expect(packaged.content_type).to eq 'application/zip'
        expect(packaged.filename).to eq export_zip
      end

      it 'zip contains correct number of entries' do
        packaged = described_class.package(results, zip_filename: export_zip)
        entries = []
        Zip::InputStream.open(StringIO.new(packaged.data)) do |zis|
          while (entry = zis.get_next_entry)
            entries << entry.name
          end
        end
        expect(entries.size).to eq 2
      end

      it 'zip entries have correct filenames' do
        packaged = described_class.package(results, zip_filename: export_zip)
        entries = []
        Zip::InputStream.open(StringIO.new(packaged.data)) do |zis|
          while (entry = zis.get_next_entry)
            entries << entry.name
          end
        end
        expect(entries).to contain_exactly(comp1_filename, comp2_filename)
      end

      it 'zip entries contain correct data' do
        packaged = described_class.package(results, zip_filename: export_zip)
        data = {}
        Zip::InputStream.open(StringIO.new(packaged.data)) do |zis|
          while (entry = zis.get_next_entry)
            data[entry.name] = zis.read
          end
        end
        expect(data[comp1_filename]).to eq 'csv-data-1'
        expect(data[comp2_filename]).to eq 'csv-data-2'
      end
    end
  end
end
