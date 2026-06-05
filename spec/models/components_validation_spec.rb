# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  context 'component release' do
    it 'onlies allow release when all rules are locked' do
      expect(@p1_c1.valid?).to be(true)
      @p1_c1.released = true
      expect(@p1_c1.valid?).to be(false)
      expect(@p1_c1.errors[:base]).to include('Cannot release a component that contains rules that are not yet locked')
    end

    it 'onlies allow depending on a released component' do
      p1_c2 = Component.new(project: @p1, name: 'Photon OS 3 V2', title: 'Photon OS 3 STIG V2', version: 'Photon OS 3 V1R2', prefix: 'PHOS-03', based_on: @srg,
                            component_id: @p1_c1.id)
      expect(p1_c2.valid?).to be(false)
      expect(p1_c2.errors[:base]).to include('Cannot overlay a component that has not been released')

      # release the component
      @p1_c1.rules.update(locked: true)
      @p1_c1.update(released: true)
      p1_c2.component.reload
      expect(p1_c2.valid?).to be(true)
    end

    it 'blocks a component from becoming unreleased' do
      @p1_c1.rules.update(locked: true)
      @p1_c1.released = true
      expect(@p1_c1.valid?).to be(true)
      @p1_c1.save

      @p1_c1.released = false
      expect(@p1_c1.valid?).to be(false)
      expect(@p1_c1.errors[:base]).to include('Cannot unrelease a released component')
    end
  end

  context 'component_id validation' do
    it 'does not allow component to overlay itself' do
      expect(@p1_c1.valid?).to be(true)
      @p1_c1.component_id = @p1_c1.id
      expect(@p1_c1.valid?).to be(false)
      expect(@p1_c1.errors[:component_id]).to include('cannot overlay itself')
    end
  end

  context 'prefix validation' do
    it 'is not nil or blank' do
      expect(@p1_c1.valid?).to be(true)

      @p1_c1.prefix = nil
      expect(@p1_c1.valid?).to be(false)

      @p1_c1.prefix = ''
      expect(@p1_c1.valid?).to be(false)

      @p1_c1.prefix = '      '
      expect(@p1_c1.valid?).to be(false)
    end

    it 'validates format' do
      expect(@p1_c1.valid?).to be(true)

      @p1_c1.prefix = '1111-AA'
      expect(@p1_c1.valid?).to be(true)

      @p1_c1.prefix = 'AAAA00'
      expect(@p1_c1.valid?).to be(false)

      @p1_c1.prefix = 'AAA1-00'
      expect(@p1_c1.valid?).to be(true)

      @p1_c1.prefix = ' AAAA-00 '
      expect(@p1_c1.valid?).to be(false)
    end
  end
end
