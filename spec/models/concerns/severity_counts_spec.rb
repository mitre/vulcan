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
RSpec.describe SeverityCounts do
  # Don't use anonymous test class - use real Component model
  # (The concern is designed to work with real models that have proper associations)

  # Use real models with their actual behavior
  # Component auto-creates rules from SRG on creation
  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:component) { create(:component, based_on: srg) }

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
        json = instance.as_json(only: %i[id title])

        expect(json).to include('id', 'title')
        expect(json).to have_key(:severity_counts)
        expect(json).not_to include('version')
      end
    end

    # NOTE: include_severity_counts: false requires models to respect it in their as_json override
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
    let_it_be(:stig) { create(:stig) }

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

  describe 'heavy column exclusion' do
    # REQUIREMENT: with_severity_counts must NOT load xml/binary columns.
    # These columns store multi-MB STIG/SRG XML documents. Loading them on
    # index pages blows Heroku dyno memory (R14/R15) and causes 30s timeouts (H12).
    # The xml column is only needed for export/download, not for listing.

    it 'excludes xml columns from STIG queries' do
      stig = create(:stig)
      loaded = Stig.with_severity_counts.find(stig.id)

      # The record should NOT have the xml attribute loaded
      expect(loaded.has_attribute?(:xml)).to be false
    end

    it 'excludes xml columns from SRG queries' do
      loaded = SecurityRequirementsGuide.with_severity_counts.find(srg.id)

      expect(loaded.has_attribute?(:xml)).to be false
    end

    it 'still includes all non-blob columns for STIGs' do
      stig = create(:stig)
      loaded = Stig.with_severity_counts.find(stig.id)

      expected_cols = Stig.columns.reject { |c| SeverityCounts::HEAVY_COLUMN_TYPES.include?(c.type) }
                          .map(&:name)
      expected_cols.each do |col|
        expect(loaded.has_attribute?(col)).to be(true), "Expected #{col} to be loaded"
      end
    end

    it 'still includes all non-blob columns for SRGs' do
      loaded = SecurityRequirementsGuide.with_severity_counts.find(srg.id)

      expected_cols = SecurityRequirementsGuide.columns
                                               .reject { |c| SeverityCounts::HEAVY_COLUMN_TYPES.include?(c.type) }
                                               .map(&:name)
      expected_cols.each do |col|
        expect(loaded.has_attribute?(col)).to be(true), "Expected #{col} to be loaded"
      end
    end

    it 'does not affect models without heavy columns (Component)' do
      loaded = Component.with_severity_counts.find(component.id)

      # Component has no xml column — all columns should be present
      expect(loaded.has_attribute?(:id)).to be true
      expect(loaded.has_attribute?(:name)).to be true
      expect(loaded.has_attribute?(:description)).to be true
    end

    it 'xml is still loadable via explicit query (for export/download)' do
      stig = create(:stig)

      # Direct find without scope — loads everything including xml
      full_stig = Stig.find(stig.id)
      expect(full_stig.has_attribute?(:xml)).to be true
    end
  end
end
