# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: Export::Base orchestrates mode + formatter to produce export
# output. The critical contract is that WorkingCopy + CSV produces
# BYTE-IDENTICAL output to Component#csv_export for the same component.
#
# This is the integration test that proves the new service system works.
# ==========================================================================
RSpec.describe Export::Base do
  let(:component) { create(:component) }
  let(:project) { component.project }

  describe '#call with working_copy + csv' do
    subject(:export) do
      described_class.new(exportable: component, mode: :working_copy, format: :csv)
    end

    it 'returns an Export::Result' do
      result = export.call
      expect(result).to be_a(Export::Result)
    end

    it 'produces CSV with correct headers' do
      result = export.call
      parsed = CSV.parse(result.data)
      expect(parsed.first).to eq ExportConstants::EXPORT_HEADERS
    end

    it 'produces correct number of data rows (one per rule)' do
      result = export.call
      parsed = CSV.parse(result.data)
      expect(parsed.size - 1).to eq component.rules.count
    end

    it 'produces BYTE-IDENTICAL output to Component#csv_export' do
      old_output = component.csv_export
      new_output = export.call.data
      expect(new_output).to eq old_output
    end

    it 'sets correct filename' do
      result = export.call
      expect(result.filename).to include(component.prefix)
      expect(result.filename).to end_with('.csv')
    end

    it 'sets correct content_type' do
      result = export.call
      expect(result.content_type).to eq 'text/csv'
    end
  end

  describe '#call with project exportable (multiple components)' do
    let!(:component2) { create(:component, project: project) }

    subject(:export) do
      described_class.new(exportable: project, mode: :working_copy, format: :csv)
    end

    it 'returns an Export::Result' do
      result = export.call
      expect(result).to be_a(Export::Result)
    end

    it 'produces a zip when project has multiple components' do
      result = export.call
      expect(result.content_type).to eq 'application/zip'
    end

    it 'zip contains one entry per component' do
      result = export.call
      entries = []
      Zip::InputStream.open(StringIO.new(result.data)) do |zis|
        while (entry = zis.get_next_entry)
          entries << entry.name
        end
      end
      expect(entries.size).to eq project.components.count
    end

    it 'each zip entry is byte-identical to individual Component#csv_export' do
      result = export.call
      data_by_entry = {}
      Zip::InputStream.open(StringIO.new(result.data)) do |zis|
        while (entry = zis.get_next_entry)
          # Zip reads return ASCII-8BIT; force to UTF-8 for comparison
          data_by_entry[entry.name] = zis.read.force_encoding('UTF-8')
        end
      end

      project.components.each do |comp|
        entry_name = data_by_entry.keys.find { |k| k.include?(comp.prefix) }
        expect(entry_name).to be_present, "No zip entry found for component #{comp.prefix}"
        expect(data_by_entry[entry_name]).to eq comp.csv_export
      end
    end
  end

  describe 'validation' do
    it 'raises for invalid mode + format combination' do
      expect do
        described_class.new(exportable: component, mode: :working_copy, format: :xccdf)
      end.to raise_error(Export::Registry::InvalidCombination)
    end

    it 'raises for nil exportable' do
      expect do
        described_class.new(exportable: nil, mode: :working_copy, format: :csv)
      end.to raise_error(ArgumentError)
    end
  end

  describe '#call with specific component_ids' do
    let!(:component2) { create(:component, project: project) }

    it 'exports only specified components when component_ids given' do
      export = described_class.new(
        exportable: project,
        mode: :working_copy,
        format: :csv,
        component_ids: [component.id]
      )
      result = export.call
      # Single component = direct file, not zip
      expect(result.content_type).to eq 'text/csv'
      expect(result.data).to eq component.csv_export
    end
  end
end
