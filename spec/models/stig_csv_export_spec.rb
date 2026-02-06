# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Stig, '#csv_export' do
  let(:stig) do
    # Create without triggering after_create (which imports rules from XML)
    Stig.insert!({ stig_id: 'test_stig', title: 'RHEL 9 STIG', name: 'RHEL 9 STIG',
                   version: 'V1R1', xml: '<xml/>',
                   created_at: Time.current, updated_at: Time.current })
    Stig.find_by!(stig_id: 'test_stig')
  end
  let!(:rule1) do
    create(:stig_rule,
           stig: stig,
           rule_id: 'SV-001r100_rule',
           version: 'RHEL-09-000001',
           srg_id: 'SRG-OS-000001',
           vuln_id: 'V-001',
           rule_severity: 'high',
           title: 'First rule',
           fixtext: 'Fix first rule.',
           ident: 'CCI-000366')
  end
  let!(:rule2) do
    create(:stig_rule,
           stig: stig,
           rule_id: 'SV-002r200_rule',
           version: 'RHEL-09-000002',
           srg_id: 'SRG-OS-000002',
           vuln_id: 'V-002',
           rule_severity: 'medium',
           title: 'Second rule',
           fixtext: 'Fix second rule.',
           ident: 'CCI-000213')
  end

  # REQUIREMENTS:
  # 1. csv_export generates valid CSV with headers and data rows
  # 2. Default columns are the 12 core fields
  # 3. Column selection: pass array of column keys to include only those
  # 4. Rules are ordered by version, rule_id
  # 5. Headers match ExportConstants::STIG_CSV_COLUMNS definitions

  describe 'with default columns' do
    it 'generates valid CSV' do
      csv_string = stig.csv_export
      csv = CSV.parse(csv_string, headers: true)
      expect(csv).to be_a(CSV::Table)
    end

    it 'has correct number of data rows' do
      csv = CSV.parse(stig.csv_export, headers: true)
      expect(csv.size).to eq(2)
    end

    it 'includes all default column headers' do
      csv = CSV.parse(stig.csv_export, headers: true)
      expect(csv.headers).to include('Rule ID', 'STIG ID', 'SRG ID', 'Vuln ID',
                                     'Severity', 'Title', 'Description', 'Check',
                                     'Fix', 'CCI', '800-53 Controls', 'Legacy IDs')
    end

    it 'does not include optional columns by default' do
      csv = CSV.parse(stig.csv_export, headers: true)
      expect(csv.headers).not_to include('Status', 'Weight')
    end

    it 'contains correct rule data' do
      csv = CSV.parse(stig.csv_export, headers: true)
      first_row = csv.first
      expect(first_row['Rule ID']).to eq('SV-001r100_rule')
      expect(first_row['STIG ID']).to eq('RHEL-09-000001')
      expect(first_row['Severity']).to eq('high')
    end

    it 'orders rules by version then rule_id' do
      csv = CSV.parse(stig.csv_export, headers: true)
      rule_ids = csv.map { |row| row['Rule ID'] }
      expect(rule_ids).to eq(['SV-001r100_rule', 'SV-002r200_rule'])
    end
  end

  describe 'with column selection' do
    it 'includes only selected columns' do
      csv = CSV.parse(stig.csv_export(columns: %i[rule_id version rule_severity]), headers: true)
      expect(csv.headers).to eq(['Rule ID', 'STIG ID', 'Severity'])
    end

    it 'can include optional columns' do
      csv = CSV.parse(stig.csv_export(columns: %i[rule_id status rule_weight]), headers: true)
      expect(csv.headers).to include('Status', 'Weight')
    end

    it 'preserves column order from selection' do
      csv = CSV.parse(stig.csv_export(columns: %i[title rule_id rule_severity]), headers: true)
      expect(csv.headers).to eq(['Title', 'Rule ID', 'Severity'])
    end
  end
end
