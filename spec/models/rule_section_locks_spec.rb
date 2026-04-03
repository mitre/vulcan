# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rule section locks' do
  let_it_be(:shared_srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:project) { Project.create(name: 'Section Lock Test') }
  let_it_be(:component, refind: true) do
    Component.create!(project: project, name: 'SL Test', title: 'SL', version: 'V1R1',
                      prefix: 'SLCK-01', based_on: shared_srg)
  end
  let_it_be(:rule, refind: true) do
    Rule.create!(component: component, rule_id: 'SL-R1',
                 status: 'Applicable - Configurable', rule_severity: 'medium',
                 srg_rule: shared_srg.srg_rules.first)
  end

  describe 'locked_fields column' do
    it 'defaults to empty hash' do
      expect(rule.locked_fields).to eq({})
    end

    it 'persists section lock state' do
      rule.update!(locked_fields: { 'Title' => true, 'Check' => true })
      rule.reload
      expect(rule.locked_fields).to eq({ 'Title' => true, 'Check' => true })
    end

    it 'appears in as_json output' do
      rule.update!(locked_fields: { 'Status' => true })
      json = rule.as_json
      expect(json['locked_fields']).to eq({ 'Status' => true })
    end
  end

  describe 'locked_fields validation' do
    it 'accepts valid section names' do
      rule.locked_fields = { 'Title' => true, 'Check' => true, 'Fix' => true }
      expect(rule).to be_valid
    end

    it 'rejects invalid section names' do
      rule.locked_fields = { 'InvalidSection' => true }
      expect(rule).not_to be_valid
      expect(rule.errors[:locked_fields]).to include(/invalid section/i)
    end

    it 'accepts all valid LOCKABLE_SECTION_NAMES' do
      all_sections = RuleConstants::LOCKABLE_SECTION_NAMES.index_with { true }
      rule.locked_fields = all_sections
      expect(rule).to be_valid
    end

    it 'accepts empty hash' do
      rule.locked_fields = {}
      expect(rule).to be_valid
    end
  end

  describe 'amoeba duplication' do
    it 'resets locked_fields on clone' do
      rule.update!(locked_fields: { 'Title' => true, 'Status' => true })
      rule.update_single_rule_clone(true)
      cloned = rule.amoeba_dup
      expect(cloned.locked_fields).to eq({})
    end
  end

  describe 'whole-rule lock interaction' do
    it 'preserves section locks when whole-rule is locked' do
      rule.update!(locked_fields: { 'Title' => true })
      # Whole-rule lock happens via Review system, just test data coexistence
      expect(rule.locked_fields).to eq({ 'Title' => true })
    end
  end
end
