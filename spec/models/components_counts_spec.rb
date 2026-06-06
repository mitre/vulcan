# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  context 'severity_counts' do
    it 'returns aggregated severity counts' do
      # Component has rules from SRG setup (reload to load imported rules)
      components_component.reload
      counts = components_component.severity_counts
      expect(counts).to be_a(Hash)
      expect(counts.keys).to contain_exactly(:high, :medium, :low)
      expect(counts[:high]).to be >= 0
      expect(counts[:medium]).to be >= 0
      expect(counts[:low]).to be >= 0
      expect(counts[:high] + counts[:medium] + counts[:low]).to eq(components_component.rules_count)
    end

    it 'includes severity_counts in as_json when requested' do
      json = components_component.as_json(methods: [:severity_counts])
      expect(json['severity_counts']).to be_a(Hash)
      expect(json['severity_counts']['high']).to be >= 0
    end

    it 'counts high severity rules correctly' do
      # Add a high severity rule
      components_component.rules.first.update(rule_severity: 'high')
      counts = components_component.severity_counts
      expect(counts[:high]).to be >= 1
    end

    it 'counts medium severity rules correctly' do
      # Add a medium severity rule
      components_component.rules.first.update(rule_severity: 'medium')
      counts = components_component.severity_counts
      expect(counts[:medium]).to be >= 1
    end

    it 'counts low severity rules correctly' do
      # Add a low severity rule
      components_component.rules.first.update(rule_severity: 'low')
      counts = components_component.severity_counts
      expect(counts[:low]).to be >= 1
    end

    it 'returns zero counts for components with no rules' do
      empty_component = Component.create!(project: components_project, name: 'Empty Component', title: 'Empty STIG',
                                          version: 'Empty V1R1', prefix: 'EMPT-00', based_on: components_srg,
                                          skip_import_srg_rules: true)
      counts = empty_component.severity_counts
      expect(counts[:high]).to eq(0)
      expect(counts[:medium]).to eq(0)
      expect(counts[:low]).to eq(0)
    end
  end

  context 'with_severity_counts scope' do
    it 'adds severity count virtual columns' do
      components_component.reload

      component = Component.with_severity_counts.find(components_component.id)
      expect(component).to respond_to(:severity_high_count)
      expect(component).to respond_to(:severity_medium_count)
      expect(component).to respond_to(:severity_low_count)
    end

    it 'returns correct severity counts as virtual columns', :aggregate_failures do
      components_component.reload

      component = Component.with_severity_counts.find(components_component.id)

      # Verify counts are integers
      expect(component.severity_high_count).to be_a(Integer)
      expect(component.severity_medium_count).to be_a(Integer)
      expect(component.severity_low_count).to be_a(Integer)

      # Verify counts sum to total rules
      total = component.severity_high_count + component.severity_medium_count + component.severity_low_count
      expect(total).to eq(components_component.rules_count)

      # Verify counts are non-negative
      expect(component.severity_high_count).to be >= 0
      expect(component.severity_medium_count).to be >= 0
      expect(component.severity_low_count).to be >= 0
    end

    it 'handles components with no rules' do
      empty = Component.create!(project: components_project, name: 'Empty Component', title: 'Empty STIG',
                                version: 'Empty V1R1', prefix: 'EMPT-01', based_on: components_srg,
                                skip_import_srg_rules: true)

      component = Component.with_severity_counts.find(empty.id)
      expect(component.severity_high_count).to eq(0)
      expect(component.severity_medium_count).to eq(0)
      expect(component.severity_low_count).to eq(0)
    end

    it 'counts match direct rule queries (no off-by-one)', :aggregate_failures do
      components_component.reload

      # Get counts from scope
      component = Component.with_severity_counts.find(components_component.id)

      # Get counts from direct queries
      expected_high = components_component.rules.where(rule_severity: 'high').count
      expected_medium = components_component.rules.where(rule_severity: 'medium').count
      expected_low = components_component.rules.where(rule_severity: 'low').count

      # Scope counts should exactly match direct queries
      expect(component.severity_high_count).to eq(expected_high)
      expect(component.severity_medium_count).to eq(expected_medium)
      expect(component.severity_low_count).to eq(expected_low)
    end
  end

  describe '#status_counts' do
    it 'returns counts for each rule status' do
      counts = components_component.status_counts
      expect(counts).to have_key(:not_yet_determined)
      expect(counts).to have_key(:applicable_configurable)
      expect(counts).to have_key(:applicable_inherently_meets)
      expect(counts).to have_key(:applicable_does_not_meet)
      expect(counts).to have_key(:not_applicable)

      # All rules default to NYD
      total = components_component.rules.where(deleted_at: nil).count
      expect(counts[:not_yet_determined]).to eq(total)
    end

    it 'reflects status changes' do
      rule = components_component.rules.first
      rule.update!(status: 'Applicable - Configurable')

      counts = components_component.status_counts
      expect(counts[:applicable_configurable]).to eq(1)
      expect(counts[:not_yet_determined]).to eq(components_component.rules.where(deleted_at: nil).count - 1)
    end
  end

  describe '#as_json' do
    it 'includes status_counts' do
      json = components_component.as_json
      # as_json merge uses symbol keys for custom additions
      expect(json).to have_key(:status_counts)
      expect(json[:status_counts]).to have_key(:not_yet_determined)
    end

    # REQUIREMENT: as_json must not crash when based_on (SRG) is nil.
    # This can happen with legacy data or components created without an SRG link.
    it 'handles nil based_on gracefully' do
      orphan = Component.new(
        project: components_component.project, name: 'Orphan', title: 'Orphan STIG',
        version: 99, release: 1, prefix: 'ORPH-01'
      )
      # Skip validations to create a component without based_on
      orphan.save!(validate: false)

      expect { orphan.as_json }.not_to raise_error
      json = orphan.as_json
      expect(json[:based_on_title]).to be_nil
      expect(json[:based_on_version]).to be_nil

      orphan.destroy!
    end
  end
end
