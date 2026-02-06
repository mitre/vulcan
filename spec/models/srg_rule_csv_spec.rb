# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SrgRule, '#csv_value_for' do
  let(:srg) { create(:security_requirements_guide) }
  let(:srg_rule) do
    create(:srg_rule,
           security_requirements_guide: srg,
           rule_id: 'SV-200001r800001_rule',
           version: 'SRG-APP-000001-GPOS-00001',
           rule_severity: 'high',
           rule_weight: '10.0',
           title: 'The application must enforce approved authorizations',
           fixtext: 'Configure the application to enforce approved authorizations.',
           ident: 'CCI-000213',
           legacy_ids: 'V-40000',
           status: 'Applicable - Configurable')
  end

  before do
    srg_rule.disa_rule_descriptions.first.update!(
      vuln_discussion: 'Unauthorized access must be prevented.'
    )
    srg_rule.checks.first.update!(
      content: 'Verify the application enforces approved authorizations.'
    )
  end

  # REQUIREMENTS:
  # SrgRule#csv_value_for works the same as StigRule#csv_value_for
  # because csv_value_for is defined on BaseRule (shared by both).
  # SRG rules typically don't have srg_id or vuln_id populated.

  describe 'core columns' do
    it 'returns rule_id' do
      expect(srg_rule.csv_value_for(:rule_id)).to eq('SV-200001r800001_rule')
    end

    it 'returns version as SRG ID' do
      expect(srg_rule.csv_value_for(:version)).to eq('SRG-APP-000001-GPOS-00001')
    end

    it 'returns title' do
      expect(srg_rule.csv_value_for(:title)).to eq('The application must enforce approved authorizations')
    end

    it 'returns rule_severity' do
      expect(srg_rule.csv_value_for(:rule_severity)).to eq('high')
    end

    it 'returns ident as CCI' do
      expect(srg_rule.csv_value_for(:ident)).to eq('CCI-000213')
    end

    it 'returns nist_control_family' do
      expect(srg_rule.csv_value_for(:nist_control_family)).to be_a(String)
    end

    it 'returns fixtext' do
      expect(srg_rule.csv_value_for(:fixtext)).to eq('Configure the application to enforce approved authorizations.')
    end
  end

  describe 'fields not populated for SRG rules' do
    it 'returns empty string for srg_id (not populated on SRG rules)' do
      expect(srg_rule.csv_value_for(:srg_id)).to eq('')
    end

    it 'returns empty string for vuln_id (not populated on SRG rules)' do
      expect(srg_rule.csv_value_for(:vuln_id)).to eq('')
    end
  end
end
