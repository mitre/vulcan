# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
# SpreadsheetParser.peek_srg_ids(file) should:
# 1. Open a CSV or XLSX file and read the SRGID column
# 2. Handle both 'SRGID' and 'SRG ID' header formats (via HEADER_ALIASES)
# 3. Return an array of unique, non-blank SRG ID strings
# 4. NOT require an srg_id constructor parameter (class method, not instance)
# 5. Return [] for empty spreadsheets, missing SRGID column, or parse errors
# 6. Read only the SRGID column (lightweight — no full validation)

RSpec.describe SpreadsheetParser do
  include ImportConstants

  describe '.peek_srg_ids' do
    def csv_tempfile(csv_content, extension: '.csv')
      file = Tempfile.new(['test', extension])
      file.write(csv_content)
      file.close
      file
    end

    context 'with valid CSV containing SRGID column' do
      let(:csv) do
        csv_tempfile(<<~CSV)
          SRGID,STIGID,Severity,Requirement
          SRG-OS-000001-GPOS-00001,RHEL-09-000001,medium,Some requirement
          SRG-OS-000002-GPOS-00002,RHEL-09-000002,high,Another requirement
          SRG-OS-000001-GPOS-00001,RHEL-09-000003,low,Duplicate SRG ID
        CSV
      end

      after { csv.unlink }

      it 'returns unique SRG IDs from the SRGID column' do
        result = described_class.peek_srg_ids(csv.path)
        expect(result).to contain_exactly(
          'SRG-OS-000001-GPOS-00001',
          'SRG-OS-000002-GPOS-00002'
        )
      end
    end

    context 'with aliased header "SRG ID" (space)' do
      let(:csv) do
        csv_tempfile(<<~CSV)
          SRG ID,STIG ID,Severity,Title
          SRG-OS-000480-GPOS-00227,RHEL-09-000100,medium,A requirement
        CSV
      end

      after { csv.unlink }

      it 'normalizes the header and returns SRG IDs' do
        result = described_class.peek_srg_ids(csv.path)
        expect(result).to eq(['SRG-OS-000480-GPOS-00227'])
      end
    end

    context 'with empty spreadsheet (header only)' do
      let(:csv) do
        csv_tempfile(<<~CSV)
          SRGID,STIGID,Severity,Requirement
        CSV
      end

      after { csv.unlink }

      it 'returns an empty array' do
        expect(described_class.peek_srg_ids(csv.path)).to eq([])
      end
    end

    context 'with no SRGID column' do
      let(:csv) do
        csv_tempfile(<<~CSV)
          Name,Value
          foo,bar
        CSV
      end

      after { csv.unlink }

      it 'returns an empty array' do
        expect(described_class.peek_srg_ids(csv.path)).to eq([])
      end
    end

    context 'with blank SRGID values' do
      let(:csv) do
        csv_tempfile(<<~CSV)
          SRGID,STIGID
          SRG-OS-000001-GPOS-00001,RHEL-09-000001
          ,RHEL-09-000002
          ,RHEL-09-000003
        CSV
      end

      after { csv.unlink }

      it 'filters out blank values' do
        result = described_class.peek_srg_ids(csv.path)
        expect(result).to eq(['SRG-OS-000001-GPOS-00001'])
      end
    end

    context 'with unparseable file' do
      let(:bad_file) do
        file = Tempfile.new(['test', '.xlsx'])
        file.write('not a real spreadsheet')
        file.close
        file
      end

      after { bad_file.unlink }

      it 'returns an empty array instead of raising' do
        expect(described_class.peek_srg_ids(bad_file.path)).to eq([])
      end
    end
  end

  describe '#parse_and_validate' do
    # Existing behavior — ensure we don't break it.
    # SpreadsheetParser requires srg_id for full validation.

    let(:srg) { create(:security_requirements_guide) }

    it 'returns error for empty file' do
      file = Tempfile.new(['empty', '.csv'])
      file.write("SRGID,STIGID,Severity,Requirement,VulDiscussion,Status,Check,Fix,Status Justification,Artifact Description\n")
      file.close

      result = described_class.new(file.path, srg.id).parse_and_validate
      expect(result).to have_key(:error)
      expect(result[:error]).to eq('Spreadsheet is empty')

      file.unlink
    end
  end
end
