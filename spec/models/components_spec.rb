# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component, type: :model do
  before do
    srg_xml = file_fixture('U_GPOS_SRG_V2R1_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    @srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    @srg.xml = srg_xml
    @srg.save!

    @p1 = Project.create!(name: 'Photon OS 3')
    @p1_c1 = Component.create!(project: @p1, version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: @srg)
  end

  context 'component release' do
    it 'onlies allow release when all rules are locked' do
      expect(@p1_c1.valid?).to be(true)
      @p1_c1.released = true
      expect(@p1_c1.valid?).to be(false)
      expect(@p1_c1.errors[:base]).to include('Cannot release a component that contains rules that are not yet locked')
    end

    it 'onlies allow depending on a released component' do
      p1_c2 = Component.new(project: @p1, version: 'Photon OS 3 V1R2', prefix: 'PHOS-03', based_on: @srg,
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

  context 'component creation' do
    it 'can duplicate a component under the same project' do
      @p1_c1.rules.update(locked: true)
      @p1_c1.reload
      @p1_c1.update(released: true)

      p1_c2 = @p1_c1.duplicate(new_name: 'Photon OS 3', new_version: 1, new_release: 2, new_title: 'title',
                               new_description: 'desc')
      # should have the same number of rules
      expect(@p1_c1.rules.size).to eq(p1_c2.rules.size)
      # should still belong to the same SRG
      expect(@p1_c1.security_requirements_guide_id).to eq(p1_c2.security_requirements_guide_id)
      # should still belong to the same project
      expect(@p1_c1.project_id).to eq(p1_c2.project_id)
      # should not be released
      expect(p1_c2.released).to be(false)
      # should have the new name
      expect(p1_c2.name).to eq('Photon OS 3')
      # should have the new version
      expect(p1_c2.version).to eq(1)
      # should have the new release
      expect(p1_c2.release).to eq(2)
      # should have the new title
      expect(p1_c2.title).to eq('title')
      # should have the new description
      expect(p1_c2.description).to eq('desc')
    end

    it 'can create a new component from a base SRG' do
      # The creation of p1_c1 in the setup should alread have these rules created
      @p1_c1.reload
      expect(@p1_c1.rules.size).to eq(191)
    end
  end

  context 'create rule satisfaction' do
    it 'correctly establishes rule satisfactions relation when a rule is satisfied by more than one other rules' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      rule_id_two = @p1_c1.rules.second.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}, #{pref}-#{rule_id_two}"
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(@p1_c1.rules.last.satisfied_by.size).to eq(2)
    end

    it 'correctly establishes rule satisfactions relation when a rule is satisfied by another rule' do
      pref = @p1_c1.prefix
      rule_id_one = @p1_c1.rules.first.rule_id
      sb = @p1_c1.rules.last
      sb.vendor_comments = "Satisfied By: #{pref}-#{rule_id_one}"
      sb.save!
      @p1_c1.create_rule_satisfactions
      expect(@p1_c1.rules.last.satisfied_by.size).to eq(1)
    end
  end
end
