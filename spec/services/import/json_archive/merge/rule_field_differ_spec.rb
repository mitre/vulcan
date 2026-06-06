# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::RuleFieldDiffer, type: :service do
  let(:component) { create(:component) }
  let(:ours_rule) { component.rules.first }

  let(:base_theirs_hash) do
    # Snapshot the existing record into archive-shape so "no change" is
    # the baseline — any divergence below is a single deliberate edit.
    ours_rule.attributes.slice(*Rule::MERGEABLE_FIELDS)
  end

  let(:strategy) { Import::JsonArchive::Merge::Strategy.new }

  describe '#diff (no divergence)' do
    it 'returns an empty array when ours_rule and theirs_hash agree' do
      differ = described_class.new(
        ours_rule: ours_rule,
        theirs_rule_hash: base_theirs_hash,
        strategy: strategy
      )
      expect(differ.diff).to eq([])
    end
  end

  describe '#diff (single field divergence)' do
    it 'produces a FieldChange with from/to and a strategy-derived resolution' do
      ours_rule.update_columns(fixtext: 'OURS original')
      ours_rule.reload
      theirs = ours_rule.attributes.slice(*Rule::MERGEABLE_FIELDS).merge('fixtext' => 'THEIRS edited')

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)
      changes = differ.diff

      change = changes.find { |c| c.field == 'fixtext' }
      expect(change).not_to be_nil
      expect(change.from).to eq('OURS original')
      expect(change.to).to eq('THEIRS edited')
      expect(change.resolution).to eq(:conflict) # Strategy default for rule content
    end
  end

  describe '#diff (auto-resolves when only one side changed)' do
    it 'returns :auto_theirs when ours matches the implicit baseline and theirs differs' do
      # No locked fields, no SRG baseline — falls to 2-way LWW via Strategy override.
      strategy = Import::JsonArchive::Merge::Strategy.new(
        overrides: { rule: { 'title' => :theirs } }
      )
      theirs = base_theirs_hash.merge('title' => 'theirs title')

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)

      title_change = differ.diff.find { |c| c.field == 'title' }
      expect(title_change.resolution).to eq(:auto_theirs)
      expect(title_change.to).to eq('theirs title')
    end

    it 'returns :auto_ours when strategy says :ours wins' do
      strategy = Import::JsonArchive::Merge::Strategy.new(
        overrides: { rule: { 'title' => :ours } }
      )
      theirs = base_theirs_hash.merge('title' => 'theirs title')

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)

      title_change = differ.diff.find { |c| c.field == 'title' }
      expect(title_change.resolution).to eq(:auto_ours)
    end
  end

  describe '#diff (locked field — always :locked_conflict)' do
    before { ours_rule.update_columns(locked_fields: %w[title]) }

    it 'flags a locked field as :locked_conflict even when only one side changed' do
      theirs = base_theirs_hash.merge('title' => 'theirs title')

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)

      title_change = differ.diff.find { |c| c.field == 'title' }
      expect(title_change.resolution).to eq(:locked_conflict)
      expect(title_change.locked).to be(true)
    end

    it 'ignores strategy overrides for locked fields (cannot be auto-resolved)' do
      strategy = Import::JsonArchive::Merge::Strategy.new(
        overrides: { rule: { 'title' => :theirs } }
      )
      theirs = base_theirs_hash.merge('title' => 'theirs title')

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)

      title_change = differ.diff.find { |c| c.field == 'title' }
      expect(title_change.resolution).to eq(:locked_conflict)
    end
  end

  describe '#diff (callbacks are NOT fired — F14)' do
    it 'does not write to the AR instance during diffing (hash comparison)' do
      # Spy on the ours_rule — if the differ uses assign_attributes, it would
      # fire before_validation callbacks. Detect by counting persisted writes.
      original_attrs = ours_rule.attributes.slice(*Rule::MERGEABLE_FIELDS)
      theirs = base_theirs_hash.merge('title' => 'theirs title', 'fixtext' => 'theirs fix')

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)
      differ.diff

      # AR instance must be unchanged — no assign_attributes side effects.
      expect(ours_rule.attributes.slice(*Rule::MERGEABLE_FIELDS)).to eq(original_attrs)
      expect(ours_rule.changed?).to be(false)
    end
  end

  describe '#diff (derived columns excluded)' do
    it 'does not produce a change for inspec_control_file even if values differ' do
      theirs = base_theirs_hash.merge('inspec_control_file' => 'totally different')

      differ = described_class.new(ours_rule: ours_rule, theirs_rule_hash: theirs, strategy: strategy)

      expect(differ.diff.map(&:field)).not_to include('inspec_control_file')
    end
  end

  describe 'VALID_FIELD_RESOLUTIONS' do
    it 'lists all 5 known field resolutions and is frozen' do
      expect(described_class::VALID_FIELD_RESOLUTIONS)
        .to contain_exactly(:auto_ours, :auto_theirs, :auto_merged, :conflict, :locked_conflict)
      expect(described_class::VALID_FIELD_RESOLUTIONS).to be_frozen
    end
  end
end
