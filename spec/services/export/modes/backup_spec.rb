# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: Backup mode exports ALL rules regardless of status, with all
# metadata. This is for full-fidelity component backup/restore via JSON archive.
# No filtering, no transforms — preserves everything.
# ==========================================================================
RSpec.describe Export::Modes::Backup do
  subject(:mode) { described_class.new }

  describe '#rule_scope' do
    let_it_be(:component) { create(:component) }

    before do
      rules = component.rules.order(:rule_id).to_a
      raise StandardError, 'Need at least 4 rules for this test' if rules.size < 4

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
      expect(scoped.ids).to include(rules[0].id)
    end

    it 'includes NYD rules' do
      rules = component.rules.order(:rule_id).to_a
      scoped = mode.rule_scope(component.rules)
      expect(scoped.ids).to include(rules[3].id)
    end
  end

  describe '#eager_load_associations' do
    it 'includes full set of associations for complete backup' do
      assocs = mode.eager_load_associations
      flat_symbols = assocs.grep(Symbol)
      expect(flat_symbols).to include(:disa_rule_descriptions)
      expect(flat_symbols).to include(:checks)
      expect(flat_symbols).to include(:references)
      expect(flat_symbols).to include(:satisfies)
      expect(flat_symbols).to include(:satisfied_by)
    end

    it 'includes reviews with user for attribution and reactions for archive fidelity' do
      assocs = mode.eager_load_associations
      review_assoc = assocs.find { |a| a.is_a?(Hash) && a.key?(:reviews) }
      expect(review_assoc).to be_present
      expect(review_assoc[:reviews]).to eq([:user, { reactions: :user }])
    end

    it 'includes additional_answers with question for name mapping' do
      assocs = mode.eager_load_associations
      answer_assoc = assocs.find { |a| a.is_a?(Hash) && a.key?(:additional_answers) }
      expect(answer_assoc).to be_present
      expect(answer_assoc[:additional_answers]).to eq(:additional_question)
    end

    it 'carries the srg_rule lineage hop the serializer emits as srg_rule_srg_id' do
      assocs = mode.eager_load_associations
      srg_rule_assoc = assocs.find { |a| a.is_a?(Hash) && a.key?(:srg_rule) }
      expect(srg_rule_assoc).to be_present
      expect(srg_rule_assoc[:srg_rule]).to include(:security_requirements_guide)
    end
  end

  describe '#srg_eager_load_associations' do
    it 'carries the derived_from lineage hop the serializer emits as derived_from_srg_rule_srg_id' do
      assocs = mode.srg_eager_load_associations
      derived_assoc = assocs.find { |a| a.is_a?(Hash) && a.key?(:derived_from) }
      expect(derived_assoc).to be_present
      expect(derived_assoc[:derived_from]).to eq(:security_requirements_guide)
    end

    it 'includes reviews with user for attribution and reactions for archive fidelity' do
      assocs = mode.srg_eager_load_associations
      review_assoc = assocs.find { |a| a.is_a?(Hash) && a.key?(:reviews) }
      expect(review_assoc).to be_present
      expect(review_assoc[:reviews]).to eq([:user, { reactions: :user }])
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
