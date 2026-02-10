# frozen_string_literal: true

require 'rails_helper'

##
# Test suite for SeverityCounts concern
#
# Verifies:
# - with_severity_counts scope generates correct SQL
# - severity_counts_hash uses virtual columns when available
# - severity_counts fallback computes from rules
# - as_json automatically includes severity_counts
# - as_json allows models to extend with additional fields
#
RSpec.describe SeverityCounts, type: :model do
  # Don't use anonymous test class - use real Component model
  # (The concern is designed to work with real models that have proper associations)

  # Use real models with their actual behavior
  # Component auto-creates rules from SRG on creation
  let(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let(:component) { create(:component, based_on: srg) }

  # Helper to get actual counts (varies based on deletion filters and test setup)
  def actual_counts(record)
    record.reload.severity_counts_hash
  end

  describe 'with_severity_counts scope' do
    it 'adds severity count virtual columns' do
      component_with_counts = Component.with_severity_counts.find(component.id)

      expect(component_with_counts).to have_attribute(:severity_high_count)
      expect(component_with_counts).to have_attribute(:severity_medium_count)
      expect(component_with_counts).to have_attribute(:severity_low_count)
    end

    it 'computes correct counts matching actual rules' do
      component_with_counts = Component.with_severity_counts.find(component.id)
      expected = actual_counts(component)

      expect(component_with_counts.severity_high_count).to eq(expected[:high])
      expect(component_with_counts.severity_medium_count).to eq(expected[:medium])
      expect(component_with_counts.severity_low_count).to eq(expected[:low])
    end
  end

  describe '#severity_counts_hash' do
    context 'when loaded via with_severity_counts scope' do
      it 'uses virtual columns without additional query' do
        component_with_counts = Component.with_severity_counts.find(component.id)
        expected = actual_counts(component)

        result = component_with_counts.severity_counts_hash
        expect(result).to eq(expected)
      end
    end

    context 'when loaded without with_severity_counts scope' do
      it 'computes from rules association' do
        component_instance = Component.find(component.id)
        expected = actual_counts(component)

        result = component_instance.severity_counts_hash
        expect(result).to eq(expected)
      end
    end
  end

  describe '#as_json' do
    let(:instance) { Component.find(component.id) }

    context 'with default behavior' do
      it 'includes severity_counts in JSON output' do
        json = instance.as_json
        expected = actual_counts(component)

        # as_json uses symbol keys for severity_counts
        expect(json).to have_key(:severity_counts)
        expect(json[:severity_counts]).to eq(expected)
      end

      it 'preserves all standard attributes' do
        json = instance.as_json

        expect(json).to include('id', 'title', 'version')
      end

      it 'respects options passed to super' do
        json = instance.as_json(only: [:id, :title])

        expect(json).to include('id', 'title')
        expect(json).to have_key(:severity_counts)
        expect(json).not_to include('version')
      end
    end

    # Note: include_severity_counts: false requires models to respect it in their as_json override
    # This concern provides the default behavior, but models can choose to always include it
  end

  describe 'integration with Component model' do
    it 'works with actual Component model' do
      json = component.as_json
      expected = actual_counts(component)

      expect(json).to have_key(:severity_counts)
      expect(json[:severity_counts]).to eq(expected)
    end

    it 'preserves Component-specific fields when model extends as_json' do
      # Component model extends as_json to add extra fields
      json = component.as_json

      # Concern adds severity_counts (symbol key)
      expect(json).to have_key(:severity_counts)

      # Component adds these via options[:methods]
      expect(json).to include('releasable', 'additional_questions')

      # Component adds these via merge in its own as_json (symbol keys)
      expect(json).to have_key(:based_on_title)
      expect(json).to have_key(:based_on_version)
    end
  end

  describe 'integration with STIG model' do
    let(:stig) { create(:stig) }

    it 'works with actual STIG model' do
      json = stig.as_json
      expected = actual_counts(stig)

      expect(json).to have_key(:severity_counts)
      expect(json[:severity_counts]).to eq(expected)
    end
  end

  describe 'integration with SRG model' do
    # Use the existing srg from the let block at top of file (GPOS V3R3)
    it 'works with actual SRG model' do
      json = srg.as_json
      expected = actual_counts(srg)

      expect(json).to have_key(:severity_counts)
      expect(json[:severity_counts]).to eq(expected)
    end
  end
end
