# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: PublishedStig mode exports only Applicable - Configurable
# rules, excluding rules that are satisfied_by other rules. This matches
# the public STIG published by DISA on Cyber Exchange (XCCDF format).
# Used with XCCDF and InSpec formatters.
# ==========================================================================
RSpec.describe Export::Modes::PublishedStig do
  subject(:mode) { described_class.new }

  describe '#rule_scope' do
    let(:component) { create(:component) }

    before do
      # Component factory creates rules from SRG — all start as 'Not Yet Determined'.
      # Set up a mix of statuses for testing.
      rules = component.rules.order(:rule_id).to_a
      raise 'Need at least 4 rules for this test' if rules.size < 4

      rules[0].update_columns(status: 'Applicable - Configurable')
      rules[1].update_columns(status: 'Applicable - Configurable')
      rules[2].update_columns(status: 'Not Applicable')
      rules[3].update_columns(status: 'Not Yet Determined')

      # Make rules[1] satisfied_by rules[0] — rules[1] should be EXCLUDED
      RuleSatisfaction.create!(rule_id: rules[1].id, satisfied_by_rule_id: rules[0].id)
    end

    it 'includes only Applicable - Configurable rules' do
      scoped = mode.rule_scope(component.rules)
      statuses = scoped.pluck(:status).uniq
      # NOTE: satisfied_by rules report status as AC via override, but we filter by DB column
      expect(statuses).to all(eq('Applicable - Configurable'))
    end

    it 'excludes rules that are satisfied_by other rules' do
      rules = component.rules.order(:rule_id).to_a
      scoped = mode.rule_scope(component.rules)
      # rules[1] is AC but has satisfied_by — must be excluded
      expect(scoped.pluck(:id)).not_to include(rules[1].id)
    end

    it 'includes AC rules without satisfied_by relationships' do
      rules = component.rules.order(:rule_id).to_a
      scoped = mode.rule_scope(component.rules)
      # rules[0] is AC with no satisfied_by — must be included
      expect(scoped.pluck(:id)).to include(rules[0].id)
    end

    it 'excludes non-AC statuses (NA, NYD, AIM, ADNM)' do
      rules = component.rules.order(:rule_id).to_a
      scoped = mode.rule_scope(component.rules)
      expect(scoped.pluck(:id)).not_to include(rules[2].id) # NA
      expect(scoped.pluck(:id)).not_to include(rules[3].id) # NYD
    end
  end

  describe '#eager_load_associations' do
    it 'includes associations needed for XCCDF/InSpec generation' do
      assocs = mode.eager_load_associations
      expect(assocs).to be_an(Array)
      expect(assocs).to include(:disa_rule_descriptions)
      expect(assocs).to include(:checks)
      expect(assocs).to include(:satisfies)
      expect(assocs).to include(:satisfied_by)
    end
  end

  describe '#component_based_columns' do
    it 'does not require columns (component-based formatters handle structure)' do
      # PublishedStig is used with XCCDF/InSpec which are component-based.
      # columns returns an empty array because the formatter handles structure.
      expect(mode.columns).to eq([])
    end

    it 'does not require headers' do
      expect(mode.headers).to eq([])
    end
  end
end
