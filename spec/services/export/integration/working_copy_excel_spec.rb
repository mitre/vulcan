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
  let_it_be(:component) { create(:component) }
  let_it_be(:project) { component.project }

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

    it 'has all 21 headers including InSpec Control Body and Source' do
      workbook = read_xlsx(result.data)
      headers = workbook.sheet(0).row(1)
      expect(headers.size).to eq 21
      expect(headers).to include('InSpec Control Body', 'Source')
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
    subject(:result) do
      Export::Base.new(exportable: project, mode: :working_copy, format: :excel).call
    end

    let_it_be(:component2) { create(:component, project: project) }

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
end
