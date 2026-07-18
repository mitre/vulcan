# frozen_string_literal: true

require 'rails_helper'

# End-state guard for the multi-parent derivation schema migration.
#
# A component derives from 1..N SRG parents. The `component_source_srgs`
# join table carries the full parent set; `based_on`
# (components.security_requirements_guide_id) stays the primary parent and
# becomes NOT NULL once every component has been backfilled into the join.
# `security_requirements_guides.core` flags the non-public core documents.
#
# This card is schema only — the join model, associations, and the
# "based_on ∈ join, ≥1 parent" invariant are the sibling card. Backfill of
# existing rows is verified against real data by the live rails-runner check
# in the card notes (the test DB has no components at migration time); the
# backfill SQL logic is exercised here against factory data.
RSpec.describe 'Multi-parent derivation schema' do
  let(:connection) { ActiveRecord::Base.connection }

  describe 'component_source_srgs join table' do
    it 'exists' do
      expect(connection.table_exists?(:component_source_srgs)).to be true
    end

    it 'has a non-null component_id' do
      column = connection.columns(:component_source_srgs).find { |c| c.name == 'component_id' }
      expect(column).to be_present
      expect(column.null).to be false
    end

    it 'has a non-null security_requirements_guide_id' do
      column = connection.columns(:component_source_srgs).find { |c| c.name == 'security_requirements_guide_id' }
      expect(column).to be_present
      expect(column.null).to be false
    end

    it 'has timestamps' do
      names = connection.columns(:component_source_srgs).map(&:name)
      expect(names).to include('created_at', 'updated_at')
    end

    it 'enforces one row per (component, parent) with a unique index' do
      expected_columns = %w[component_id security_requirements_guide_id].sort
      index = connection.indexes(:component_source_srgs).find { |i| i.columns.sort == expected_columns }
      expect(index).to be_present
      expect(index.unique).to be true
    end

    it 'has a foreign key on component_id → components' do
      fk = connection.foreign_keys(:component_source_srgs).find { |f| f.column == 'component_id' }
      expect(fk).to be_present
      expect(fk.to_table).to eq('components')
    end

    it 'has a foreign key on security_requirements_guide_id → security_requirements_guides' do
      fk = connection.foreign_keys(:component_source_srgs).find { |f| f.column == 'security_requirements_guide_id' }
      expect(fk).to be_present
      expect(fk.to_table).to eq('security_requirements_guides')
    end
  end

  describe 'components.security_requirements_guide_id (primary parent)' do
    it 'is NOT NULL after backfill' do
      column = connection.columns(:components).find { |c| c.name == 'security_requirements_guide_id' }
      expect(column.null).to be false
    end
  end

  describe 'security_requirements_guides.core' do
    it 'is a boolean defaulting to false, non-null' do
      column = connection.columns(:security_requirements_guides).find { |c| c.name == 'core' }
      expect(column).to be_present
      expect(column.type).to eq(:boolean)
      expect(column.null).to be false
      expect(column.default).to eq('false')
    end

    it 'defaults a newly created SRG to non-core' do
      srg = create(:security_requirements_guide)
      expect(srg.reload.read_attribute(:core)).to be false
    end
  end
end
