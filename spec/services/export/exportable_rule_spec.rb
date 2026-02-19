# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: ExportableRule wraps a Rule and provides named key-based
# access to the 20 export columns. Each key must return the same value
# that Rule#csv_attributes returns at the corresponding positional index.
#
# This decorator replaces positional array indexing with named keys,
# making mode transforms and formatter access clear and maintainable.
# ==========================================================================
RSpec.describe Export::ExportableRule do
  let_it_be(:component) { create(:component) }
  let(:rule) { component.rules.first }
  let(:exportable) { described_class.new(rule) }

  # These are the 20 column keys that map to csv_attributes positions 0-18 + inspec_control_body
  describe '#value_for' do
    it 'returns nist_control_family (position 0)' do
      expect(exportable.value_for(:nist_control_family)).to eq rule.nist_control_family
    end

    it 'returns ident (position 1)' do
      expect(exportable.value_for(:ident)).to eq rule.ident
    end

    it 'returns srg_id from rule.version (position 2)' do
      expect(exportable.value_for(:srg_id)).to eq rule.version
    end

    it 'returns stig_id as prefix-rule_id (position 3)' do
      expect(exportable.value_for(:stig_id)).to eq "#{component.prefix}-#{rule.rule_id}"
    end

    it 'returns srg_title from srg_rule.title (position 4)' do
      expect(exportable.value_for(:srg_title)).to eq rule.srg_rule.title
    end

    it 'returns title (position 5)' do
      expect(exportable.value_for(:title)).to eq rule.title
    end

    it 'returns srg_vuln_discussion (position 6)' do
      expect(exportable.value_for(:srg_vuln_discussion)).to eq rule.srg_rule.disa_rule_descriptions.first&.vuln_discussion
    end

    it 'returns vuln_discussion (position 7)' do
      expect(exportable.value_for(:vuln_discussion)).to eq rule.disa_rule_descriptions.first&.vuln_discussion
    end

    it 'returns status (position 8)' do
      expect(exportable.value_for(:status)).to eq rule.status
    end

    it 'returns srg_check from srg_rule.checks (position 9)' do
      expect(exportable.value_for(:srg_check)).to eq rule.srg_rule.checks.first&.content
    end

    it 'returns check_content matching csv_attributes position 10' do
      # export_checktext is private — verify against csv_attributes directly
      expect(exportable.value_for(:check_content)).to eq rule.csv_attributes[10]
    end

    it 'returns srg_fix from srg_rule.fixtext (position 11)' do
      expect(exportable.value_for(:srg_fix)).to eq rule.srg_rule.fixtext
    end

    it 'returns fixtext matching csv_attributes position 12' do
      # export_fixtext is private — verify against csv_attributes directly
      expect(exportable.value_for(:fixtext)).to eq rule.csv_attributes[12]
    end

    it 'returns severity mapped through SEVERITIES_MAP (position 13)' do
      expected = RuleConstants::SEVERITIES_MAP[rule.rule_severity] || rule.rule_severity
      expect(exportable.value_for(:severity)).to eq expected
    end

    it 'returns mitigation (position 14)' do
      expect(exportable.value_for(:mitigation)).to eq rule.disa_rule_descriptions.first&.mitigations
    end

    it 'returns artifact_description (position 15)' do
      expect(exportable.value_for(:artifact_description)).to eq rule.artifact_description
    end

    it 'returns status_justification (position 16)' do
      expect(exportable.value_for(:status_justification)).to eq rule.status_justification
    end

    it 'returns vendor_comments (position 17)' do
      expect(exportable.value_for(:vendor_comments)).to eq rule.vendor_comments
    end

    it 'returns satisfies text (position 18)' do
      expect(exportable.value_for(:satisfies)).to eq rule.satisfaction_text(format: :stig, direction: :satisfies)
    end

    it 'returns inspec_control_body (position 19)' do
      expect(exportable.value_for(:inspec_control_body)).to eq rule.inspec_control_body
    end

    it 'raises for unknown key' do
      expect { exportable.value_for(:nonexistent) }.to raise_error(ArgumentError)
    end
  end

  describe '#values_for' do
    it 'returns array of values for given keys in order' do
      keys = %i[status title severity]
      values = exportable.values_for(keys)
      expect(values).to eq [
        rule.status,
        rule.title,
        RuleConstants::SEVERITIES_MAP[rule.rule_severity] || rule.rule_severity
      ]
    end
  end

  describe '#csv_attributes_match' do
    it 'produces the same 19-element array as Rule#csv_attributes' do
      # ExportableRule should be able to reproduce the exact csv_attributes output
      csv_keys = Export::ExportableRule::CSV_KEYS
      values = exportable.values_for(csv_keys)
      expect(values).to eq rule.csv_attributes
    end
  end

  describe '#rule delegation' do
    it 'delegates rule model methods' do
      expect(exportable.rule).to eq rule
      expect(exportable.status).to eq rule.status
    end
  end
end
