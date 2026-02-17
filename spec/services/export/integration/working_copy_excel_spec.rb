# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# INTEGRATION TEST: WorkingCopy + Excel end-to-end
#
# Verifies the full export pipeline for standard Excel:
# - All 20 columns including InSpec Control Body
# - All rules included (including NYD)
# - No field-blanking transforms
# - Multi-component produces multi-sheet workbook
# ==========================================================================
RSpec.describe 'WorkingCopy + Excel integration' do
  let(:component) { create(:component) }
  let(:project) { component.project }

  describe 'single component' do
    subject(:result) do
      Export::Base.new(
        exportable: project,
        mode: :working_copy,
        format: :excel,
        component_ids: [component.id]
      ).call
    end

    it 'returns an Export::Result with Excel content type' do
      expect(result.content_type).to eq 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end

    it 'has all 20 headers including InSpec Control Body' do
      workbook = read_xlsx(result.data)
      headers = workbook.sheet(0).row(1)
      expect(headers.size).to eq 20
      expect(headers.last).to eq 'InSpec Control Body'
    end

    it 'includes all rules (no filtering)' do
      workbook = read_xlsx(result.data)
      data_rows = parse_data_rows(workbook, 0)
      expect(data_rows.size).to eq component.rules.count
    end

    it 'has one worksheet named after the component' do
      workbook = read_xlsx(result.data)
      expect(workbook.sheets.size).to eq 1
      expect(workbook.sheets.first).to include(component.name.gsub(/\s+/, '')[0..10])
    end
  end

  describe 'multi component' do
    let!(:component2) { create(:component, project: project) }

    subject(:result) do
      Export::Base.new(exportable: project, mode: :working_copy, format: :excel).call
    end

    it 'produces a single workbook (not zip)' do
      expect(result.content_type).to eq 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end

    it 'has one worksheet per component' do
      workbook = read_xlsx(result.data)
      expect(workbook.sheets.size).to eq 2
    end

    it 'each sheet has the correct row count' do
      workbook = read_xlsx(result.data)

      sheet0_rows = parse_data_rows(workbook, 0)
      sheet1_rows = parse_data_rows(workbook, 1)

      components = project.components.sort_by(&:id)
      expect(sheet0_rows.size).to eq components[0].rules.count
      expect(sheet1_rows.size).to eq components[1].rules.count
    end
  end

  private

  def read_xlsx(binary_data)
    tmpfile = Tempfile.new(['test', '.xlsx'])
    tmpfile.binmode
    tmpfile.write(binary_data)
    tmpfile.close
    workbook = Roo::Spreadsheet.open(tmpfile.path)
    workbook.instance_variable_set(:@_tmpfile, tmpfile)
    workbook
  end

  def parse_data_rows(workbook, sheet_index)
    workbook.sheet(sheet_index).parse(headers: true).drop(1)
  end
end
