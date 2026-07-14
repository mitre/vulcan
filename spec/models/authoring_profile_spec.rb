# frozen_string_literal: true

require 'rails_helper'

# The authoring-profile registry: ONE frozen Ruby table keyed by
# Component#document_type carrying the per-profile CONFIGURATION variance —
# status vocabulary, field-config key, parent-eligibility policy, panel
# set. Behavioral variance rides the STI classes; this registry must never
# be a DB table. Adding a third profile means adding a row here, not a
# migration.
RSpec.describe AuthoringProfile do
  describe 'the registry' do
    it 'knows exactly the stig and srg profiles' do
      expect(described_class.keys).to eq(%w[stig srg])
    end

    it 'raises KeyError for an unknown profile key' do
      expect { described_class.for('bogus') }.to raise_error(KeyError)
    end

    it 'is deeply frozen — registry, profiles, and vocabularies' do
      expect(described_class::REGISTRY).to be_frozen
      described_class::REGISTRY.each_key do |key|
        profile = described_class.for(key)
        expect(profile).to be_frozen
        expect(profile.statuses).to be_frozen
      end
    end
  end

  describe 'the stig profile' do
    subject(:profile) { described_class.for('stig') }

    it 'keeps exactly today\'s five statuses' do
      expect(profile.statuses).to eq(
        [
          'Not Yet Determined',
          'Applicable - Configurable',
          'Applicable - Inherently Meets',
          'Applicable - Does Not Meet',
          'Not Applicable'
        ]
      )
    end

    it 'carries the stig field-config key, any-SRG parent policy, and the Rule-only panels' do
      expect(profile.field_config_key).to eq('stig')
      expect(profile.parent_eligibility).to eq(:any_srg)
      expect(profile.panels).to eq(%i[satisfies inspec stig_answers])
    end
  end

  describe 'the srg profile' do
    subject(:profile) { described_class.for('srg') }

    it 'has exactly the three-value SRG vocabulary — bare Applicable, no Moved' do
      expect(profile.statuses).to eq(['Not Yet Determined', 'Applicable', 'Not Applicable'])
    end

    it 'carries the srg field-config key, core-SRGs parent policy, and no Rule-only panels' do
      expect(profile.field_config_key).to eq('srg')
      expect(profile.parent_eligibility).to eq(:core_srgs)
      expect(profile.panels).to eq([])
    end
  end

  describe 'Component integration' do
    it 'validates document_type against the registry keys' do
      component = build(:component, :skip_rules, document_type: 'bogus')
      expect(component).not_to be_valid
      expect(component.errors[:document_type]).to include('is not included in the list')
    end
  end
end
