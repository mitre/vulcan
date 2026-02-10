# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecurityRequirementsGuide, type: :model do
  let(:srg) { create(:security_requirements_guide) }

  context 'severity_counts' do
    it 'returns aggregated severity counts' do
      counts = srg.severity_counts
      expect(counts).to be_a(Hash)
      expect(counts.keys).to contain_exactly(:high, :medium, :low)
      expect(counts[:high]).to be >= 0
      expect(counts[:medium]).to be >= 0
      expect(counts[:low]).to be >= 0
    end

    it 'includes severity_counts in as_json when requested' do
      json = srg.as_json(methods: [:severity_counts])
      expect(json['severity_counts']).to be_a(Hash)
    end
  end

  context 'with_severity_counts scope' do
    it 'adds severity count virtual columns' do
      loaded_srg = SecurityRequirementsGuide.with_severity_counts.find(srg.id)
      expect(loaded_srg).to respond_to(:severity_high_count)
      expect(loaded_srg).to respond_to(:severity_medium_count)
      expect(loaded_srg).to respond_to(:severity_low_count)
    end

    it 'counts match direct queries', :aggregate_failures do
      loaded_srg = SecurityRequirementsGuide.with_severity_counts.find(srg.id)

      # Verify counts match direct rule queries
      expected_high = srg.srg_rules.where(rule_severity: 'high').count
      expected_medium = srg.srg_rules.where(rule_severity: 'medium').count
      expected_low = srg.srg_rules.where(rule_severity: 'low').count

      expect(loaded_srg.severity_high_count).to eq(expected_high)
      expect(loaded_srg.severity_medium_count).to eq(expected_medium)
      expect(loaded_srg.severity_low_count).to eq(expected_low)
    end
  end
end
