# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::Strategy, type: :service do
  describe 'defaults' do
    let(:strategy) { described_class.new }

    it 'returns :conflict default for rule content fields' do
      expect(strategy.for_field(:rule, 'check_content')).to eq(:conflict)
      expect(strategy.for_field(:rule, 'fixtext')).to eq(:conflict)
      expect(strategy.for_field(:rule, 'vuln_discussion')).to eq(:conflict)
    end

    it 'returns :newer for component-level metadata so drift is recoverable' do
      expect(strategy.for_field(:component, 'description')).to eq(:newer)
    end

    it 'returns :union for memberships (additive)' do
      expect(strategy.for_entity(:memberships)).to eq(:union)
    end

    it 'returns :union for satisfactions (set-like)' do
      expect(strategy.for_entity(:satisfactions)).to eq(:union)
    end

    it 'returns :ours for review triage_status (we own our triage)' do
      expect(strategy.for_field(:review, 'triage_status')).to eq(:ours)
    end
  end

  describe '#locked_field_resolution' do
    it 'always returns :conflict regardless of overrides' do
      strategy = described_class.new(overrides: { rule: { 'check_content' => :theirs } })
      expect(strategy.locked_field_resolution).to eq(:conflict)
    end
  end

  describe 'overrides' do
    it 'merges per-entity overrides on top of defaults' do
      strategy = described_class.new(overrides: { rule: { 'check_content' => :theirs } })
      expect(strategy.for_field(:rule, 'check_content')).to eq(:theirs)
      expect(strategy.for_field(:rule, 'fixtext')).to eq(:conflict) # still default
    end

    it 'supports per-entity blanket overrides via the :_default key' do
      strategy = described_class.new(overrides: { rule: { _default: :theirs } })
      expect(strategy.for_field(:rule, 'check_content')).to eq(:theirs)
      expect(strategy.for_field(:rule, 'fixtext')).to eq(:theirs)
    end
  end

  describe 'VALID_STRATEGY_RESOLUTIONS' do
    it 'lists all 7 known resolutions' do
      expect(described_class::VALID_STRATEGY_RESOLUTIONS)
        .to contain_exactly(:ours, :theirs, :newer, :conflict, :union, :skip, :manual)
    end

    it 'is frozen so callers cannot mutate it' do
      expect(described_class::VALID_STRATEGY_RESOLUTIONS).to be_frozen
    end

    it 'rejects unknown resolutions at construction' do
      expect { described_class.new(overrides: { rule: { 'check_content' => :nuke_from_orbit } }) }
        .to raise_error(ArgumentError, /resolution/i)
    end
  end

  describe 'DEFAULT_STRATEGY' do
    it 'is frozen' do
      expect(described_class::DEFAULT_STRATEGY).to be_frozen
    end
  end
end
