# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: WorkingCopy mode exports all rules with all columns (including
# InSpec control body). No filtering, no transforms — identity pass-through.
# This is the "just give me everything" export for internal team use.
# ==========================================================================
RSpec.describe Export::Modes::WorkingCopy do
  subject(:mode) { described_class.new }

  describe '#columns' do
    it 'includes all 20 export keys' do
      expect(mode.columns.size).to eq 20
    end

    it 'includes inspec_control_body' do
      expect(mode.columns).to include(:inspec_control_body)
    end

    it 'starts with nist_control_family and ends with inspec_control_body' do
      expect(mode.columns.first).to eq :nist_control_family
      expect(mode.columns.last).to eq :inspec_control_body
    end
  end

  describe '#headers' do
    it 'returns ExportConstants::EXPORT_HEADERS' do
      expect(mode.headers).to eq ExportConstants::EXPORT_HEADERS
    end

    it 'has same count as columns' do
      expect(mode.headers.size).to eq mode.columns.size
    end
  end

  describe '#rule_scope' do
    let(:component) { create(:component) }

    it 'returns all rules (no filtering)' do
      rules = component.rules
      expect(mode.rule_scope(rules)).to eq rules
    end
  end

  describe '#transform_value' do
    it 'returns value unchanged (identity transform)' do
      expect(mode.transform_value(:status, 'some value', nil)).to eq 'some value'
    end
  end

  describe '#eager_load_associations' do
    it 'returns the associations needed for CSV export' do
      assocs = mode.eager_load_associations
      expect(assocs).to be_an(Array)
      expect(assocs).to include(:disa_rule_descriptions)
      expect(assocs).to include(:checks)
      expect(assocs).to include(:satisfies)
      expect(assocs).to include(:satisfied_by)
    end
  end
end
