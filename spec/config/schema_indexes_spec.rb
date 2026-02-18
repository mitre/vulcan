# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'base_rules table indexes', type: :model do
  # These tests assert that critical composite indexes exist on the base_rules
  # table. They were added for query performance (filtering by severity, type,
  # soft-delete) and data integrity (unique rule per component). If a future
  # migration accidentally drops one, these tests will catch it.

  let(:indexes) { ActiveRecord::Base.connection.indexes('base_rules') }

  def find_index(name)
    indexes.find { |idx| idx.name == name }
  end

  shared_examples 'an index with correct columns' do |index_name, expected_columns, description|
    it "exists with correct columns (#{expected_columns.join(', ')})" do
      idx = find_index(index_name)
      expect(idx).to be_present, "composite index on #{expected_columns} is missing (#{description})"
      expect(idx.columns).to eq(expected_columns)
    end
  end

  describe 'component severity composite index' do
    it_behaves_like 'an index with correct columns',
                    'index_base_rules_on_component_deleted_severity',
                    %w[component_id deleted_at rule_severity],
                    'filtering component rules by severity excluding soft-deleted'
  end

  describe 'SRG type/severity composite index' do
    it_behaves_like 'an index with correct columns',
                    'index_base_rules_on_srg_type_severity',
                    %w[security_requirements_guide_id type rule_severity],
                    'querying SRG rules by STI type and severity'
  end

  describe 'STIG type/severity composite index' do
    it_behaves_like 'an index with correct columns',
                    'index_base_rules_on_stig_type_severity',
                    %w[stig_id type rule_severity],
                    'querying STIG rules by STI type and severity'
  end

  describe 'rule_id + component_id unique index' do
    # Prevents duplicate rules within a single component.
    it 'exists with correct columns and is unique' do
      idx = find_index('rule_id_and_component_id')
      expect(idx).to be_present, 'unique index on [rule_id, component_id] is missing'
      expect(idx.columns).to eq(%w[rule_id component_id])
      expect(idx.unique).to be(true), 'index on [rule_id, component_id] must be unique'
    end
  end
end
