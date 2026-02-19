# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StigRule, '#csv_value_for' do
  let(:none_identified) { 'None identified.' }
  let(:stig_rule) do
    create(:stig_rule,
           stig: stig,
           rule_id: 'SV-203591r557031_rule',
           version: 'RHEL-09-000001',
           srg_id: 'SRG-OS-000001-GPOS-00001',
           vuln_id: 'V-203591',
           rule_severity: 'medium',
           rule_weight: '10.0',
           title: 'The operating system must audit events',
           fixtext: 'Configure the operating system to audit events.',
           ident: 'CCI-000366',
           legacy_ids: 'V-56571, SV-70831',
           status: 'Applicable - Configurable')
  end

  let_it_be(:stig) { create(:stig) }

  before do
    # Update the auto-created associated records (before_create creates empty ones)
    stig_rule.disa_rule_descriptions.first.update!(
      vuln_discussion: 'Without verification of the security functions.',
      mitigations: 'Use compensating controls.',
      false_positives: none_identified,
      false_negatives: none_identified,
      severity_override_guidance: 'Override if compensating controls exist.'
    )
    stig_rule.checks.first.update!(
      content: 'Verify the operating system audits events.'
    )
  end

  # REQUIREMENTS:
  # csv_value_for returns the correct value for each column key.
  # This is the core method that maps column keys to actual data.

  describe 'default columns' do
    it 'returns rule_id' do
      expect(stig_rule.csv_value_for(:rule_id)).to eq('SV-203591r557031_rule')
    end

    it 'returns version as STIG ID' do
      expect(stig_rule.csv_value_for(:version)).to eq('RHEL-09-000001')
    end

    it 'returns srg_id' do
      expect(stig_rule.csv_value_for(:srg_id)).to eq('SRG-OS-000001-GPOS-00001')
    end

    it 'returns vuln_id' do
      expect(stig_rule.csv_value_for(:vuln_id)).to eq('V-203591')
    end

    it 'returns rule_severity' do
      expect(stig_rule.csv_value_for(:rule_severity)).to eq('medium')
    end

    it 'returns title' do
      expect(stig_rule.csv_value_for(:title)).to eq('The operating system must audit events')
    end

    it 'returns vuln_discussion from disa_rule_descriptions' do
      expect(stig_rule.csv_value_for(:vuln_discussion)).to eq('Without verification of the security functions.')
    end

    it 'returns check_content from checks' do
      expect(stig_rule.csv_value_for(:check_content)).to eq('Verify the operating system audits events.')
    end

    it 'returns fixtext' do
      expect(stig_rule.csv_value_for(:fixtext)).to eq('Configure the operating system to audit events.')
    end

    it 'returns ident as CCI' do
      expect(stig_rule.csv_value_for(:ident)).to eq('CCI-000366')
    end

    it 'returns nist_control_family as 800-53 Controls' do
      expect(stig_rule.csv_value_for(:nist_control_family)).to be_a(String)
      expect(stig_rule.csv_value_for(:nist_control_family)).not_to be_empty
    end

    it 'returns legacy_ids' do
      expect(stig_rule.csv_value_for(:legacy_ids)).to eq('V-56571, SV-70831')
    end
  end

  describe 'optional columns' do
    it 'returns status' do
      expect(stig_rule.csv_value_for(:status)).to eq('Applicable - Configurable')
    end

    it 'returns rule_weight' do
      expect(stig_rule.csv_value_for(:rule_weight)).to eq('10.0')
    end

    it 'returns mitigations' do
      expect(stig_rule.csv_value_for(:mitigations)).to eq('Use compensating controls.')
    end

    it 'returns severity_override_guidance' do
      expect(stig_rule.csv_value_for(:severity_override_guidance)).to eq('Override if compensating controls exist.')
    end

    it 'returns false_positives' do
      expect(stig_rule.csv_value_for(:false_positives)).to eq(none_identified)
    end

    it 'returns false_negatives' do
      expect(stig_rule.csv_value_for(:false_negatives)).to eq(none_identified)
    end
  end

  describe 'edge cases' do
    it 'returns empty string for unknown column' do
      expect(stig_rule.csv_value_for(:nonexistent)).to eq('')
    end

    it 'returns empty string when disa_rule_description is nil' do
      stig_rule.disa_rule_descriptions.destroy_all
      # Trigger before_create callback won't fire since already created
      expect(stig_rule.csv_value_for(:vuln_discussion)).to eq('')
    end

    it 'returns empty string when check is nil' do
      stig_rule.checks.destroy_all
      expect(stig_rule.csv_value_for(:check_content)).to eq('')
    end

    it 'returns empty string for nil legacy_ids' do
      stig_rule.update!(legacy_ids: nil)
      expect(stig_rule.csv_value_for(:legacy_ids)).to eq('')
    end
  end
end
