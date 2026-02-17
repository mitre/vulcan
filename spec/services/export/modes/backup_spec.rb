# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: Backup mode exports ALL rules regardless of status, with all
# metadata. This is for full-fidelity component backup/restore via XCCDF.
# No filtering, no transforms — preserves everything.
# ==========================================================================
RSpec.describe Export::Modes::Backup do
  subject(:mode) { described_class.new }

  describe '#rule_scope' do
    let(:component) { create(:component) }

    before do
      rules = component.rules.order(:rule_id).to_a
      raise 'Need at least 4 rules for this test' if rules.size < 4

      rules[0].update_columns(status: 'Applicable - Configurable')
      rules[1].update_columns(status: 'Not Applicable')
      rules[2].update_columns(status: 'Applicable - Does Not Meet')
      rules[3].update_columns(status: 'Not Yet Determined')

      # Add a satisfied_by relationship — backup should still include it
      RuleSatisfaction.create!(rule_id: rules[0].id, satisfied_by_rule_id: rules[1].id)
    end

    it 'includes ALL rules regardless of status' do
      scoped = mode.rule_scope(component.rules)
      expect(scoped.count).to eq(component.rules.count)
    end

    it 'includes rules with satisfied_by relationships' do
      rules = component.rules.order(:rule_id).to_a
      scoped = mode.rule_scope(component.rules)
      expect(scoped.pluck(:id)).to include(rules[0].id)
    end

    it 'includes NYD rules' do
      rules = component.rules.order(:rule_id).to_a
      scoped = mode.rule_scope(component.rules)
      expect(scoped.pluck(:id)).to include(rules[3].id)
    end
  end

  describe '#eager_load_associations' do
    it 'includes full set of associations for complete backup' do
      assocs = mode.eager_load_associations
      expect(assocs).to be_an(Array)
      expect(assocs).to include(:disa_rule_descriptions)
      expect(assocs).to include(:checks)
      expect(assocs).to include(:satisfies)
      expect(assocs).to include(:satisfied_by)
    end
  end

  describe '#component_based_columns' do
    it 'does not require columns (component-based formatters handle structure)' do
      expect(mode.columns).to eq([])
    end

    it 'does not require headers' do
      expect(mode.headers).to eq([])
    end
  end
end
