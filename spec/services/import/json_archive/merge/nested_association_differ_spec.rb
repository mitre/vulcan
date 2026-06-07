# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::NestedAssociationDiffer, type: :service do
  let(:component) { create(:component) }
  let(:ours_rule) { component.rules.first }
  let(:strategy) { Import::JsonArchive::Merge::Strategy.new }

  # Helper: build a theirs_rule_hash with nested associations from the current
  # state of ours_rule, then let each spec mutate.
  def theirs_for(rule)
    {
      'checks' => rule.checks.map do |c|
        c.attributes.except('id', 'base_rule_id', 'created_at', 'updated_at')
      end,
      'disa_rule_descriptions' => rule.disa_rule_descriptions.map do |d|
        d.attributes.except('id', 'base_rule_id', 'created_at', 'updated_at')
      end
    }
  end

  describe '#diff (no divergence)' do
    it 'returns an empty array when nested data agrees on both sides' do
      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs_for(ours_rule), strategy: strategy)
      expect(differ.diff).to eq([])
    end
  end

  describe '#diff (DisaRuleDescription divergence — vuln_discussion)' do
    let(:theirs) do
      base = theirs_for(ours_rule)
      base['disa_rule_descriptions'].first['vuln_discussion'] = 'THEIRS edited vuln'
      base
    end

    it 'detects a vuln_discussion change and reports it with the right field name' do
      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)
      change = differ.diff.find { |c| c.field == 'vuln_discussion' }

      expect(change).not_to be_nil
      expect(change.to).to eq('THEIRS edited vuln')
      expect(change.resolution).to eq(:conflict) # Strategy default for rule content
    end

    it 'flags as :locked_conflict when the Vulnerability Discussion section is locked' do
      ours_rule.update_columns(locked_fields: { 'Vulnerability Discussion' => true })

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)
      change = differ.diff.find { |c| c.field == 'vuln_discussion' }

      expect(change.resolution).to eq(:locked_conflict)
      expect(change.locked).to be(true)
    end
  end

  describe '#diff (Check divergence — content / check_content lock)' do
    let(:theirs) do
      base = theirs_for(ours_rule)
      base['checks'].first['content'] = 'THEIRS edited check content'
      base
    end

    it 'detects a Check#content change' do
      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)
      change = differ.diff.find { |c| c.field == 'content' }
      expect(change).not_to be_nil
      expect(change.to).to eq('THEIRS edited check content')
    end

    it 'flags as :locked_conflict when the Check section is locked (Scenario C tripwire)' do
      ours_rule.update_columns(locked_fields: { 'Check' => true })

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)
      change = differ.diff.find { |c| c.field == 'content' }

      expect(change.resolution).to eq(:locked_conflict)
      expect(change.locked).to be(true)
    end
  end

  describe '#diff (callback safety — F14 holds for nested too)' do
    it 'does not write to AR instances during diffing' do
      original_attrs = ours_rule.disa_rule_descriptions.first.attributes
      theirs = theirs_for(ours_rule)
      theirs['disa_rule_descriptions'].first['vuln_discussion'] = 'changed'

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)
      differ.diff

      expect(ours_rule.disa_rule_descriptions.first.attributes).to eq(original_attrs)
      expect(ours_rule.disa_rule_descriptions.first.changed?).to be(false)
    end
  end

  describe '#diff (identity-key pairing for checks)' do
    it 'pairs Check records by `system` when multiple exist per rule' do
      # Create a second check with a different system
      ours_rule.checks.create!(system: 'C.2', content: 'second check')
      ours_rule.reload

      theirs = theirs_for(ours_rule)
      # Edit the second check's content; verify the change attaches to that
      # check and not the first one
      theirs['checks'].find { |c| c['system'] == 'C.2' }['content'] = 'second edited'

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)
      changes = differ.diff.select { |c| c.field == 'content' }

      expect(changes.size).to eq(1)
      expect(changes.first.from).to eq('second check')
      expect(changes.first.to).to eq('second edited')
    end
  end
end
