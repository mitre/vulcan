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
end
