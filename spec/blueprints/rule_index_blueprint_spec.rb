# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RuleIndexBlueprint do
  let(:component) { create(:component) }

  describe 'basic fields' do
    let(:rule) { create(:rule, component: component) }

    subject(:result) { described_class.render_as_hash(rule) }

    it 'includes core identification fields' do
      expect(result).to include(
        id: rule.id,
        rule_id: rule.rule_id,
        version: rule.version,
        title: rule.title
      )
    end

    it 'includes status fields' do
      expect(result).to include(
        status: rule.status,
        rule_severity: rule.rule_severity
      )
    end

    it 'includes review fields' do
      expect(result).to include(
        locked: rule.locked,
        review_requestor_id: rule.review_requestor_id,
        changes_requested: rule.changes_requested
      )
    end

    it 'includes timestamp' do
      expect(result).to have_key(:updated_at)
    end
  end

  describe '#is_merged' do
    let(:rule) { create(:rule, component: component) }

    subject(:result) { described_class.render_as_hash(rule) }

    context 'when rule has no satisfied_by relationships' do
      it 'returns false' do
        expect(result[:is_merged]).to be false
      end
    end

    context 'when rule is satisfied by another rule' do
      let(:parent_rule) { create(:rule, component: component) }

      before do
        # rule is satisfied by parent_rule (rule is the child)
        rule.satisfied_by << parent_rule
      end

      it 'returns true' do
        expect(result[:is_merged]).to be true
      end
    end
  end

  describe '#satisfies_count' do
    let(:rule) { create(:rule, component: component) }

    subject(:result) { described_class.render_as_hash(rule) }

    context 'when rule satisfies no other rules' do
      it 'returns 0' do
        expect(result[:satisfies_count]).to eq(0)
      end
    end

    context 'when rule satisfies other rules' do
      let(:child_rule1) { create(:rule, component: component) }
      let(:child_rule2) { create(:rule, component: component) }
      let(:child_rule3) { create(:rule, component: component) }

      before do
        # rule satisfies child_rule1, child_rule2, child_rule3
        rule.satisfies << child_rule1
        rule.satisfies << child_rule2
        rule.satisfies << child_rule3
      end

      it 'returns the correct count' do
        expect(result[:satisfies_count]).to eq(3)
      end
    end
  end

  describe '#satisfies_rules' do
    let(:rule) { create(:rule, component: component) }

    subject(:result) { described_class.render_as_hash(rule) }

    context 'when rule satisfies no other rules' do
      it 'returns empty array' do
        expect(result[:satisfies_rules]).to eq([])
      end
    end

    context 'when rule satisfies other rules' do
      let(:child_rule1) { create(:rule, component: component, title: 'Child Rule 1') }
      let(:child_rule2) { create(:rule, component: component, title: 'Child Rule 2') }

      before do
        rule.satisfies << child_rule1
        rule.satisfies << child_rule2
      end

      it 'returns array of satisfied rules with id, rule_id, and title' do
        satisfies_rules = result[:satisfies_rules]

        expect(satisfies_rules).to be_an(Array)
        expect(satisfies_rules.length).to eq(2)

        expect(satisfies_rules).to include(
          hash_including(id: child_rule1.id, rule_id: child_rule1.rule_id, title: 'Child Rule 1')
        )
        expect(satisfies_rules).to include(
          hash_including(id: child_rule2.id, rule_id: child_rule2.rule_id, title: 'Child Rule 2')
        )
      end

      it 'returns only required fields (not full rule data)' do
        satisfies_rules = result[:satisfies_rules]

        satisfies_rules.each do |satisfied_rule|
          expect(satisfied_rule.keys).to contain_exactly(:id, :rule_id, :title)
        end
      end
    end
  end

  describe 'collection rendering' do
    # Create rules fresh for this describe block
    let!(:parent_rule) { create(:rule, component: component) }
    let!(:child_rule1) { create(:rule, component: component) }
    let!(:child_rule2) { create(:rule, component: component) }

    before do
      # parent_rule satisfies child_rule1 and child_rule2
      parent_rule.satisfies << child_rule1
      parent_rule.satisfies << child_rule2
      # Reload to pick up the associations
      parent_rule.reload
      child_rule1.reload
      child_rule2.reload
    end

    subject(:results) { described_class.render_as_hash([parent_rule, child_rule1, child_rule2]) }

    it 'renders all rules as an array' do
      expect(results).to be_an(Array)
      expect(results.length).to eq(3)
    end

    it 'correctly identifies parent rule' do
      parent = results.find { |r| r[:id] == parent_rule.id }
      expect(parent[:satisfies_count]).to eq(2)
      expect(parent[:is_merged]).to be false
    end

    it 'correctly identifies child rules' do
      child1 = results.find { |r| r[:id] == child_rule1.id }
      child2 = results.find { |r| r[:id] == child_rule2.id }

      expect(child1[:is_merged]).to be true
      expect(child2[:is_merged]).to be true
      expect(child1[:satisfies_count]).to eq(0)
      expect(child2[:satisfies_count]).to eq(0)
    end

    it 'includes satisfied_by array for child rules' do
      child1 = results.find { |r| r[:id] == child_rule1.id }

      expect(child1[:satisfied_by]).to be_an(Array)
      expect(child1[:satisfied_by].length).to eq(1)
      expect(child1[:satisfied_by].first).to include(
        id: parent_rule.id,
        rule_id: parent_rule.rule_id,
        title: parent_rule.title
      )
    end

    it 'includes empty satisfied_by array for parent rules' do
      parent = results.find { |r| r[:id] == parent_rule.id }

      expect(parent[:satisfied_by]).to be_an(Array)
      expect(parent[:satisfied_by]).to be_empty
    end
  end
end
