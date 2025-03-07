# filepath: /Users/alippold/github/mitre/vulcan/spec/models/base_rule_spec.rb
require 'rails_helper'

RSpec.describe BaseRule, type: :model do
  describe 'associations' do
    it { should have_many(:rule_descriptions).dependent(:destroy) }
    it { should have_many(:disa_rule_descriptions).dependent(:destroy) }
    it { should have_many(:checks).dependent(:destroy) }
    it { should have_many(:references).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:status).in_array(BaseRule::STATUSES) }
    it { should validate_inclusion_of(:rule_severity).in_array(BaseRule::SEVERITIES) }
  end

  describe 'factories' do
    it 'creates a valid BaseRule' do
      base_rule = FactoryBot.build(:base_rule)
      expect(base_rule).to be_valid
    end
  end

  describe '#from_mapping' do
    it 'creates a BaseRule from a rule mapping' do
      rule_mapping = double('RuleMapping',
                            id: 'rule-123',
                            status: [double('Status', status: 'Approved')],
                            severity: 'high',
                            weight: '20.0',
                            version: [double('Version', version: '2.0')],
                            title: [double('Title', first: 'Test Rule')],
                            ident: [double('Ident', ident: 'CCI-000002', system: 'CCI', legacy: false)],
                            fixtext: [double('Fixtext', fixtext: 'Fix it', fixref: 'fixref')],
                            fix: [double('Fix', id: 'fix-2')],
                            reference: [double('Reference')]
                           )

      allow(Reference).to receive(:from_mapping).and_return({})
      allow(DisaRuleDescription).to receive(:from_mapping).and_return({})
      allow(Check).to receive(:from_mapping).and_return({})

      rule = BaseRule.from_mapping(BaseRule, rule_mapping)

      expect(rule.rule_id).to eq('rule-123')
      expect(rule.status).to eq('Approved')
      expect(rule.rule_severity).to eq('high')
      expect(rule.rule_weight).to eq('20.0')
      expect(rule.version).to eq('2.0')
      expect(rule.title).to eq('Test Rule')
      expect(rule.ident).to eq('CCI-000002')
      expect(rule.fixtext).to eq('Fix it')
      expect(rule.fixtext_fixref).to eq('fixref')
      expect(rule.fix_id).to eq('fix-2')
    end
  end

  describe '#as_json' do
    it 'includes dependent records in json' do
      base_rule = FactoryBot.create(:base_rule)
      json = base_rule.as_json
      expect(json).to include(:rule_descriptions_attributes, :disa_rule_descriptions_attributes, :checks_attributes, :nist_control_family, :version, :locked, :review_requestor_id, :changes_requested)
    end
  end

  describe '#nist_control_family' do
    it 'returns the NIST control family based on CCI' do
      base_rule = FactoryBot.create(:base_rule, ident: 'CCI-000001, CCI-000002')
      expect(base_rule.nist_control_family).to eq('AC, AU')
    end

    it 'returns an empty string if there are no CCIs' do
      base_rule = FactoryBot.create(:base_rule, ident: '')
      expect(base_rule.nist_control_family).to eq('')
    end
  end

  describe 'callbacks' do
    it 'ensures disa_rule_description exists before create' do
      base_rule = FactoryBot.build(:base_rule, disa_rule_descriptions: [])
      base_rule.save
      expect(base_rule.disa_rule_descriptions).not_to be_empty
    end

    it 'ensures check exists before create' do
      base_rule = FactoryBot.build(:base_rule, checks: [])
      base_rule.save
      expect(base_rule.checks).not_to be_empty
    end
  end
end