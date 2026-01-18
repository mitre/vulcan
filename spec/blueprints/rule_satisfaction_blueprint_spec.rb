# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RuleSatisfactionBlueprint do
  let(:component) { create(:component) }
  let(:rule) { create(:rule, component: component, title: 'Test Rule Title') }

  describe 'basic fields' do
    subject(:result) { described_class.render_as_hash(rule) }

    it 'includes id' do
      expect(result).to include(id: rule.id)
    end

    it 'includes rule_id' do
      expect(result).to include(rule_id: rule.rule_id)
    end

    it 'includes title' do
      expect(result).to include(title: 'Test Rule Title')
    end

    it 'includes fixtext' do
      expect(result).to have_key(:fixtext)
    end
  end

  describe 'when used in satisfaction context' do
    let(:parent_rule) { create(:rule, component: component, title: 'Parent Rule') }
    let(:child_rule) { create(:rule, component: component, title: 'Child Rule') }

    before do
      # parent_rule satisfies child_rule (child_rule is satisfied by parent_rule)
      parent_rule.satisfies << child_rule
      # Reload to ensure associations are fresh
      parent_rule.reload
      child_rule.reload
    end

    it 'serializes satisfies relationship with title' do
      # Get parent's satisfies list
      satisfies_result = parent_rule.satisfies.map { |r| described_class.render_as_hash(r) }

      expect(satisfies_result.first).to include(
        id: child_rule.id,
        rule_id: child_rule.rule_id,
        title: 'Child Rule'
      )
    end

    it 'serializes satisfied_by relationship with title' do
      # Get child's satisfied_by list
      satisfied_by_result = child_rule.satisfied_by.map { |r| described_class.render_as_hash(r) }

      expect(satisfied_by_result.first).to include(
        id: parent_rule.id,
        rule_id: parent_rule.rule_id,
        title: 'Parent Rule'
      )
    end
  end

  describe 'collection rendering' do
    let(:rule1) { create(:rule, component: component, title: 'Rule One') }
    let(:rule2) { create(:rule, component: component, title: 'Rule Two') }

    it 'renders all rules with titles' do
      result = described_class.render_as_hash([rule1, rule2])

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |r| r[:title] }).to contain_exactly('Rule One', 'Rule Two')
    end
  end
end
