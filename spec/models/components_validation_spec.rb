# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  context 'component release' do
    it 'onlies allow release when all rules are locked' do
      expect(components_component.valid?).to be(true)
      components_component.released = true
      expect(components_component.valid?).to be(false)
      expect(components_component.errors[:base]).to include('Cannot release a component that contains rules that are not yet locked')
    end

    it 'onlies allow depending on a released component' do
      p1_c2 = Component.new(project: components_project, name: 'Photon OS 3 V2', title: 'Photon OS 3 STIG V2', version: 'Photon OS 3 V1R2', prefix: 'PHOS-03', based_on: components_srg,
                            component_id: components_component.id)
      expect(p1_c2.valid?).to be(false)
      expect(p1_c2.errors[:base]).to include('Cannot overlay a component that has not been released')

      # release the component
      components_component.rules.update(locked: true)
      components_component.update(released: true)
      p1_c2.component.reload
      expect(p1_c2.valid?).to be(true)
    end

    it 'blocks a component from becoming unreleased' do
      components_component.rules.update(locked: true)
      components_component.released = true
      expect(components_component.valid?).to be(true)
      components_component.save

      components_component.released = false
      expect(components_component.valid?).to be(false)
      expect(components_component.errors[:base]).to include('Cannot unrelease a released component')
    end
  end

  context 'component_id validation' do
    it 'does not allow component to overlay itself' do
      expect(components_component.valid?).to be(true)
      components_component.component_id = components_component.id
      expect(components_component.valid?).to be(false)
      expect(components_component.errors[:component_id]).to include('cannot overlay itself')
    end
  end

  context 'prefix validation' do
    it 'is not nil or blank' do
      expect(components_component.valid?).to be(true)

      components_component.prefix = nil
      expect(components_component.valid?).to be(false)

      components_component.prefix = ''
      expect(components_component.valid?).to be(false)

      components_component.prefix = '      '
      expect(components_component.valid?).to be(false)
    end

    it 'validates format' do
      expect(components_component.valid?).to be(true)

      components_component.prefix = '1111-AA'
      expect(components_component.valid?).to be(true)

      components_component.prefix = 'AAAA00'
      expect(components_component.valid?).to be(false)

      components_component.prefix = 'AAA1-00'
      expect(components_component.valid?).to be(true)

      components_component.prefix = ' AAAA-00 '
      expect(components_component.valid?).to be(false)
    end
  end

  describe '#prefix= auto-upcase' do
    it 'upcases lowercase prefix on assignment' do
      components_component.prefix = 'abcd-01'
      expect(components_component.prefix).to eq('ABCD-01')
    end

    it 'handles nil without error' do
      components_component.prefix = nil
      expect(components_component.prefix).to be_nil
    end
  end

  describe '#releasable' do
    it 'returns false when already released' do
      components_component.rules.update_all(locked: true)
      components_component.update!(released: true)
      expect(components_component.releasable).to be(false)
    end
  end

  describe '#largest_rule_id' do
    it 'returns the highest numeric rule_id' do
      max_id = components_component.rules.pluck(:rule_id).map(&:to_i).max
      expect(components_component.largest_rule_id).to eq(max_id)
    end

    it 'returns nil for component with no rules' do
      empty = Component.create!(project: components_project, name: 'Empty', title: 'E',
                                version: 'V1R1', prefix: 'EMPT-99', based_on: components_srg,
                                skip_import_srg_rules: true)
      expect(empty.largest_rule_id).to eq(0)
      empty.destroy!
    end
  end
end
