# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe SecurityRequirementsGuide, '#csv_export' do
  let(:header_rule_id) { 'Rule ID' }
  let(:header_srg_id) { 'SRG ID' }

  let(:srg) do
    # Create without triggering after_create (which imports rules from XML)
    SecurityRequirementsGuide.insert!({ srg_id: 'test_srg', title: 'Web Server SRG',
                                        name: 'Web Server SRG', version: 'V2R3', xml: '<xml/>',
                                        created_at: Time.current, updated_at: Time.current })
    SecurityRequirementsGuide.find_by!(srg_id: 'test_srg')
  end
  let!(:rule1) do
    create(:srg_rule,
           security_requirements_guide: srg,
           rule_id: 'SV-100001r900001_rule',
           version: 'SRG-APP-000001-GPOS-00001',
           rule_severity: 'high',
           title: 'First SRG requirement',
           fixtext: 'Fix first requirement.',
           ident: 'CCI-000213')
  end
  let!(:rule2) do
    create(:srg_rule,
           security_requirements_guide: srg,
           rule_id: 'SV-100002r900002_rule',
           version: 'SRG-APP-000002-GPOS-00002',
           rule_severity: 'medium',
           title: 'Second SRG requirement',
           fixtext: 'Fix second requirement.',
           ident: 'CCI-000366')
  end

  # REQUIREMENTS:
  # 1. Same pattern as Stig#csv_export
  # 2. Default columns exclude STIG-specific fields (version/STIG ID, vuln_id)
  # 3. Column selection works the same way

  describe 'with default columns' do
    it 'generates valid CSV' do
      csv_string = srg.csv_export
      csv = CSV.parse(csv_string, headers: true)
      expect(csv).to be_a(CSV::Table)
    end

    it 'has correct number of data rows' do
      csv = CSV.parse(srg.csv_export, headers: true)
      expect(csv.size).to eq(2)
    end

    it 'includes SRG default column headers' do
      csv = CSV.parse(srg.csv_export, headers: true)
      # version column shows "SRG ID" (not "STIG ID") in SRG context
      expect(csv.headers).to include(header_rule_id, header_srg_id, 'Severity', 'Title',
                                     'Description', 'Check', 'Fix', 'CCI',
                                     '800-53 Controls', 'Legacy IDs')
    end

    it 'does not include STIG-specific columns by default' do
      csv = CSV.parse(srg.csv_export, headers: true)
      # SRG default columns don't include STIG ID or Vuln ID
      expect(csv.headers).not_to include('STIG ID')
      expect(csv.headers).not_to include('Vuln ID')
    end

    it 'contains correct rule data' do
      csv = CSV.parse(srg.csv_export, headers: true)
      first_row = csv.first
      expect(first_row[header_rule_id]).to eq('SV-100001r900001_rule')
      # version column shows as "SRG ID" in SRG context
      expect(first_row[header_srg_id]).to eq('SRG-APP-000001-GPOS-00001')
    end
  end

  describe 'with column selection' do
    it 'includes only selected columns' do
      csv = CSV.parse(srg.csv_export(columns: %i[rule_id version]), headers: true)
      # version → "SRG ID" in SRG context
      expect(csv.headers).to eq([header_rule_id, header_srg_id])
    end
  end
end
