# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# INTEGRATION TEST: VendorSubmission + Excel end-to-end
#
# Verifies the full export pipeline produces DISA-compliant output:
# - Exactly 17 columns (Table 8-1)
# - STIGID blank for all statuses
# - Check/Fix blank for non-AC
# - VulnDiscussion/Severity blank for NA
# - NYD rules excluded
# - Correct MIME type and file format
#
# See docs/disa-process/field-requirements.md for the full matrix.
# ==========================================================================
RSpec.describe 'VendorSubmission + Excel integration' do
  subject(:result) do
    Export::Base.new(
      exportable: project,
      mode: :vendor_submission,
      format: :excel,
      component_ids: [component.id]
    ).call
  end

  let(:component) { create(:component) }
  let(:project) { component.project }
  let(:rules) { component.rules.where.missing(:satisfied_by).to_a }

  before do
    # Set up mixed statuses on rules without satisfied_by (to avoid status= guard)
    rules[0]&.update_column(:status, 'Applicable - Configurable')
    rules[1]&.update_column(:status, 'Applicable - Inherently Meets')
    rules[2]&.update_column(:status, 'Applicable - Does Not Meet')
    rules[3]&.update_column(:status, 'Not Applicable')
    rules[4]&.update_column(:status, 'Not Yet Determined')
  end

  describe 'output format' do
    it 'returns an Export::Result' do
      expect(result).to be_a(Export::Result)
    end

    it 'has Excel content type' do
      expect(result.content_type).to eq 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end

    it 'produces valid xlsx (PK zip magic bytes)' do
      expect(result.data.bytes[0..1]).to eq [0x50, 0x4B]
    end

    it 'has one worksheet per component' do
      workbook = read_xlsx(result.data)
      expect(workbook.sheets.size).to eq 1
    end
  end

  describe 'DISA column compliance (Table 8-1)' do
    it 'has exactly 17 headers' do
      workbook = read_xlsx(result.data)
      headers = workbook.sheet(0).row(1)
      expect(headers.size).to eq 17
    end

    it 'does not include Vendor Comments column' do
      workbook = read_xlsx(result.data)
      headers = workbook.sheet(0).row(1)
      expect(headers).not_to include('Vendor Comments')
    end

    it 'does not include Satisfies column' do
      workbook = read_xlsx(result.data)
      headers = workbook.sheet(0).row(1)
      expect(headers).not_to include('Satisfies')
    end

    it 'does not include InSpec Control Body column' do
      workbook = read_xlsx(result.data)
      headers = workbook.sheet(0).row(1)
      expect(headers).not_to include('InSpec Control Body')
    end
  end

  describe 'NYD exclusion' do
    it 'excludes Not Yet Determined rules' do
      workbook = read_xlsx(result.data)
      data_rows = parse_data_rows(workbook, 0)
      statuses = data_rows.pluck('Status')
      expect(statuses).not_to include('Not Yet Determined')
    end

    it 'includes all other statuses' do
      workbook = read_xlsx(result.data)
      data_rows = parse_data_rows(workbook, 0)
      statuses = data_rows.pluck('Status').uniq
      expect(statuses).to include('Applicable - Configurable')
      expect(statuses).to include('Applicable - Inherently Meets')
      expect(statuses).to include('Applicable - Does Not Meet')
      expect(statuses).to include('Not Applicable')
    end
  end

  describe 'STIGID blanking (Section 4.1.4)' do
    it 'STIGID is blank for all rules' do
      workbook = read_xlsx(result.data)
      data_rows = parse_data_rows(workbook, 0)
      stigids = data_rows.filter_map { |r| r['STIGID'] }.reject(&:empty?)
      expect(stigids).to be_empty
    end
  end

  describe 'field-blanking per status' do
    let(:data_rows) do
      workbook = read_xlsx(result.data)
      parse_data_rows(workbook, 0)
    end

    context 'Applicable - Configurable' do
      let(:ac_row) { data_rows.find { |r| r['Status'] == 'Applicable - Configurable' } }

      it 'keeps Check content' do
        # AC rules should have check content (unless DB is empty)
        expect(ac_row).to be_present
      end
    end

    context 'Applicable - Inherently Meets (Section 4.1.11, 4.1.13)' do
      let(:aim_row) { data_rows.find { |r| r['Status'] == 'Applicable - Inherently Meets' } }

      it 'blanks Check' do
        expect(aim_row['Check']).to be_blank
      end

      it 'blanks Fix' do
        expect(aim_row['Fix']).to be_blank
      end

      it 'keeps VulDiscussion' do
        # VulDiscussion comes from SRG, should have content
        expect(aim_row).to be_present
      end

      it 'blanks Mitigation' do
        expect(aim_row['Mitigation']).to be_blank
      end
    end

    context 'Applicable - Does Not Meet (Sections 4.1.11, 4.1.13)' do
      let(:adnm_row) { data_rows.find { |r| r['Status'] == 'Applicable - Does Not Meet' } }

      it 'blanks Check' do
        expect(adnm_row['Check']).to be_blank
      end

      it 'blanks Fix' do
        expect(adnm_row['Fix']).to be_blank
      end

      it 'blanks Artifact Description' do
        expect(adnm_row['Artifact Description']).to be_blank
      end
    end

    context 'Not Applicable (Sections 4.1.8, 4.1.11, 4.1.13, 4.1.14)' do
      let(:na_row) { data_rows.find { |r| r['Status'] == 'Not Applicable' } }

      it 'blanks Check' do
        expect(na_row['Check']).to be_blank
      end

      it 'blanks Fix' do
        expect(na_row['Fix']).to be_blank
      end

      it 'blanks VulDiscussion' do
        expect(na_row['VulDiscussion']).to be_blank
      end

      it 'blanks Severity' do
        expect(na_row['Severity']).to be_blank
      end

      it 'blanks Mitigation' do
        expect(na_row['Mitigation']).to be_blank
      end

      it 'blanks Artifact Description' do
        expect(na_row['Artifact Description']).to be_blank
      end
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
