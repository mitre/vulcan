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

    it 'falls back to :conflict for unknown :component-level fields (component meta does not participate in merge)' do
      expect(strategy.for_field(:component, 'description')).to eq(:conflict)
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

  describe '.resolve_verb (VERB_TRANSLATION single source of truth)' do
    it 'maps :ours to auto_ours + ours' do
      expect(described_class.resolve_verb(:ours)).to eq(resolution: :auto_ours, source: 'ours')
    end

    it 'maps :theirs to auto_theirs + theirs' do
      expect(described_class.resolve_verb(:theirs)).to eq(resolution: :auto_theirs, source: 'theirs')
    end

    it 'maps :union to auto_merged + auto_merge' do
      expect(described_class.resolve_verb(:union)).to eq(resolution: :auto_merged, source: 'auto_merge')
    end

    it ':conflict / :newer / :manual all resolve to :conflict + conflict_resolved (NOT auto_merge)' do
      %i[conflict newer manual].each do |verb|
        tuple = described_class.resolve_verb(verb)
        expect(tuple[:resolution]).to eq(:conflict), "verb=#{verb} resolution"
        expect(tuple[:source]).to eq('conflict_resolved'), "verb=#{verb} source"
      end
    end

    it 'every VALID_STRATEGY_RESOLUTIONS verb has a translation tuple' do
      missing = described_class::VALID_STRATEGY_RESOLUTIONS - described_class::VERB_TRANSLATION.keys
      expect(missing).to be_empty, "verbs missing from VERB_TRANSLATION: #{missing.inspect}"
    end

    it 'returns nil for unknown verbs (caller falls back explicitly)' do
      expect(described_class.resolve_verb(:nonsense)).to be_nil
    end
  end

  describe '#validate_resolutions! (:union rejection for scalar fields)' do
    it 'rejects :union for a rule scalar field' do
      expect do
        described_class.new(overrides: { rule: { 'fixtext' => :union } })
      end.to raise_error(ArgumentError, /:union is not valid for scalar rule/i)
    end

    it 'rejects :union for a review scalar field' do
      expect do
        described_class.new(overrides: { review: { 'triage_status' => :union } })
      end.to raise_error(ArgumentError, /:union is not valid for scalar review/i)
    end

    it 'still accepts :union for memberships (set-like entity)' do
      expect { described_class.new(overrides: { memberships: :union }) }.not_to raise_error
    end

    it 'still accepts :union for satisfactions (set-like entity)' do
      expect { described_class.new(overrides: { satisfactions: :union }) }.not_to raise_error
    end
  end
end
