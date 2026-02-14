# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stig do
  let(:stig) { create(:stig) }

  context 'validation' do
    it 'validates presence of stig_id, title, version, and xml' do
      expect(stig.stig_id).to be_present
      expect(stig.title).to be_present
      expect(stig.name).to be_present
      expect(stig.version).to be_present
      expect(stig.xml).to be_present
    end

    it 'validates uniqueness of stig_id scoped to version' do
      stig2 = stig.dup
      stig2.valid?
      expect(stig2.errors.full_messages).to include('Stig ID has already been taken')
    end
  end

  context 'severity_counts' do
    it 'returns aggregated severity counts' do
      counts = stig.severity_counts
      expect(counts).to be_a(Hash)
      expect(counts.keys).to contain_exactly(:high, :medium, :low)
      expect(counts[:high]).to be >= 0
      expect(counts[:medium]).to be >= 0
      expect(counts[:low]).to be >= 0
    end

    it 'includes severity_counts in as_json when requested' do
      json = stig.as_json(methods: [:severity_counts])
      expect(json['severity_counts']).to be_a(Hash)
    end
  end

  context 'with_severity_counts scope' do
    it 'adds severity count virtual columns' do
      loaded_stig = Stig.with_severity_counts.find(stig.id)
      expect(loaded_stig).to respond_to(:severity_high_count)
      expect(loaded_stig).to respond_to(:severity_medium_count)
      expect(loaded_stig).to respond_to(:severity_low_count)
    end

    it 'counts match direct queries', :aggregate_failures do
      loaded_stig = Stig.with_severity_counts.find(stig.id)

      # Verify counts match direct rule queries
      expected_high = stig.stig_rules.where(rule_severity: 'high').count
      expected_medium = stig.stig_rules.where(rule_severity: 'medium').count
      expected_low = stig.stig_rules.where(rule_severity: 'low').count

      expect(loaded_stig.severity_high_count).to eq(expected_high)
      expect(loaded_stig.severity_medium_count).to eq(expected_medium)
      expect(loaded_stig.severity_low_count).to eq(expected_low)
    end
  end
end
