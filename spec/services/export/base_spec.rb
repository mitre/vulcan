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
  let_it_be(:component) { create(:component) }
  let_it_be(:project) { component.project }

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
    subject(:export) do
      described_class.new(exportable: project, mode: :working_copy, format: :csv)
    end

    let_it_be(:component2) { create(:component, project: project) }

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
    let_it_be(:component2_for_ids) { create(:component, project: project) }

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

  # ==========================================================================
  # PR-717: when a Working Copy CSV export runs and a component has any
  # public-comment disposition records (top-level reviews), the disposition
  # matrix CSV is bundled into the same zip alongside the rule CSV. The
  # disposition file rides with the existing Working Copy export — no separate
  # endpoint, no separate Download button. Always-on if comments exist; absent
  # when no comments exist.
  # ==========================================================================
  describe '#call with working_copy + csv — disposition piggyback' do
    let_it_be(:dpb_project)   { create(:project) }
    let_it_be(:dpb_srg)       { create(:security_requirements_guide) }
    let_it_be(:dpb_component) { create(:component, project: dpb_project, based_on: dpb_srg) }
    let_it_be(:dpb_clean)     { create(:component, project: dpb_project, based_on: dpb_srg) }
    let_it_be(:dpb_commenter) { create(:user, name: 'Sarah K') }

    before do
      Membership.find_or_create_by!(user: dpb_commenter, membership: dpb_project) do |m|
        m.role = 'viewer'
      end
      # One top-level review on dpb_component so it has disposition data.
      # dpb_clean stays comment-free.
      Review.create!(
        rule: dpb_component.rules.first,
        user: dpb_commenter,
        action: 'comment',
        comment: 'check text issue',
        triage_status: 'pending'
      )
    end

    let(:single_component_export) do
      described_class.new(
        exportable: dpb_project,
        mode: :working_copy,
        format: :csv,
        component_ids: [dpb_component.id]
      )
    end

    let(:single_clean_export) do
      described_class.new(
        exportable: dpb_project,
        mode: :working_copy,
        format: :csv,
        component_ids: [dpb_clean.id]
      )
    end

    it 'wraps a single component-with-comments export in a zip containing rule CSV + disposition CSV' do
      result = single_component_export.call
      expect(result.content_type).to eq 'application/zip'
      entries = []
      Zip::InputStream.open(StringIO.new(result.data)) do |zis|
        while (entry = zis.get_next_entry)
          entries << entry.name
        end
      end
      expect(entries.length).to eq(2)
      expect(entries.any? { |n| n.include?('disposition-matrix') }).to be true
      expect(entries.any? { |n| n.exclude?('disposition-matrix') }).to be true
    end

    it 'leaves a single component-WITHOUT-comments export as a CSV passthrough (no disposition file)' do
      result = single_clean_export.call
      expect(result.content_type).to eq 'text/csv'
      expect(result.data).to eq dpb_clean.csv_export
    end

    it 'disposition CSV bytes match DispositionMatrixExport.generate(component:)' do
      result = single_component_export.call
      data_by_entry = {}
      Zip::InputStream.open(StringIO.new(result.data)) do |zis|
        while (entry = zis.get_next_entry)
          data_by_entry[entry.name] = zis.read.force_encoding('UTF-8')
        end
      end
      disposition_entry = data_by_entry.keys.find { |k| k.include?('disposition-matrix') }
      expect(data_by_entry[disposition_entry]).to eq DispositionMatrixExport.generate(component: dpb_component)
    end

    it 'rule CSV bytes still match Component#csv_export' do
      result = single_component_export.call
      data_by_entry = {}
      Zip::InputStream.open(StringIO.new(result.data)) do |zis|
        while (entry = zis.get_next_entry)
          data_by_entry[entry.name] = zis.read.force_encoding('UTF-8')
        end
      end
      rule_entry = data_by_entry.keys.find { |k| k.exclude?('disposition-matrix') }
      expect(data_by_entry[rule_entry]).to eq dpb_component.csv_export
    end

    it 'multi-component project export includes disposition only for components with comments' do
      export = described_class.new(exportable: dpb_project, mode: :working_copy, format: :csv)
      result = export.call
      entries = []
      Zip::InputStream.open(StringIO.new(result.data)) do |zis|
        while (entry = zis.get_next_entry)
          entries << entry.name
        end
      end
      # 2 components × 1 rule CSV each + 1 disposition CSV (dpb_component only) = 3 entries
      expect(entries.length).to eq(3)
      disposition_entries = entries.select { |n| n.include?('disposition-matrix') }
      expect(disposition_entries.length).to eq(1)
      expect(disposition_entries.first).to include(dpb_component.prefix)
    end
  end

  # ==========================================================================
  # PR-717: when a Working Copy Excel export runs and a component has any
  # public-comment disposition records, an additional disposition sheet
  # is added to the workbook for that component (alongside the rule sheet).
  # Empty workbooks still produce a single workbook file (Excel is always
  # one .xlsx artifact, never zipped) — disposition piggybacks as extra
  # sheet tabs inside it.
  # ==========================================================================
  describe '#call with working_copy + excel — disposition piggyback' do
    let_it_be(:dpe_project)   { create(:project) }
    let_it_be(:dpe_srg)       { create(:security_requirements_guide) }
    let_it_be(:dpe_component) { create(:component, project: dpe_project, based_on: dpe_srg) }
    let_it_be(:dpe_clean)     { create(:component, project: dpe_project, based_on: dpe_srg) }
    let_it_be(:dpe_commenter) { create(:user, name: 'Sarah K') }

    before do
      Membership.find_or_create_by!(user: dpe_commenter, membership: dpe_project) do |m|
        m.role = 'viewer'
      end
      Review.create!(
        rule: dpe_component.rules.first,
        user: dpe_commenter,
        action: 'comment',
        comment: 'check text issue',
        triage_status: 'pending'
      )
    end

    let(:export) do
      described_class.new(exportable: dpe_project, mode: :working_copy, format: :excel)
    end

    it 'returns a single Excel workbook (never zipped)' do
      result = export.call
      expect(result).to be_a(Export::Result)
      expect(result.content_type).to include('spreadsheet')
      expect(result.filename).to end_with('.xlsx')
    end

    it 'workbook contains a rule sheet for every component plus a disposition sheet only for components with comments' do
      result = export.call
      workbook = read_xlsx(result.data)
      # 2 rule sheets (dpe_component + dpe_clean) + 1 disposition sheet (dpe_component only)
      expect(workbook.sheets.size).to eq(3)
      disposition_sheets = workbook.sheets.select { |n| n.include?('Disp') }
      expect(disposition_sheets.size).to eq(1)
    end

    it 'disposition sheet has the locked DispositionMatrixExport headers' do
      result = export.call
      workbook = read_xlsx(result.data)
      disposition_sheet_name = workbook.sheets.find { |n| n.include?('Disp') }
      expect(disposition_sheet_name).to be_present
      header_row = workbook.sheet(disposition_sheet_name).row(1)
      expect(header_row).to eq DispositionMatrixExport::BASE_HEADERS
    end

    it 'disposition sheet rows match DispositionMatrixExport.rows_and_headers' do
      result = export.call
      workbook = read_xlsx(result.data)
      disposition_sheet_name = workbook.sheets.find { |n| n.include?('Disp') }
      data_rows = parse_data_rows(workbook, workbook.sheets.index(disposition_sheet_name))

      expected = DispositionMatrixExport.rows_and_headers(component: dpe_component)
      expect(data_rows.size).to eq(expected[:rows].size)
      first_row_id = data_rows.first['Comment ID']
      # Roo coerces numeric cells to numerics — both ends compare as numbers.
      expect(first_row_id.to_i).to eq(expected[:rows].first[0])
    end

    it 'single-component-with-comments export still returns a workbook (not a CSV)' do
      single_export = described_class.new(
        exportable: dpe_project,
        mode: :working_copy,
        format: :excel,
        component_ids: [dpe_component.id]
      )
      result = single_export.call
      workbook = read_xlsx(result.data)
      # 1 rule sheet + 1 disposition sheet
      expect(workbook.sheets.size).to eq(2)
    end

    it 'single-component-WITHOUT-comments export contributes only its rule sheet' do
      single_clean = described_class.new(
        exportable: dpe_project,
        mode: :working_copy,
        format: :excel,
        component_ids: [dpe_clean.id]
      )
      result = single_clean.call
      workbook = read_xlsx(result.data)
      expect(workbook.sheets.size).to eq(1)
    end
  end
end
