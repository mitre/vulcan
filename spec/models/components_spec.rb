# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component, type: :model do
  before(:each) do
    xml_files = ['U_NDM_SRG_V2R14_Manual-xccdf.xml', 'U_NDM_SRG_V4R1_Manual-xccdf.xml']

    xml_files.each_with_index do |f, idx|
      srg_xml = file_fixture(f).read
      parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
      srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
      srg.xml = srg_xml
      srg.save!
      instance_variable_set("@srg#{idx + 1}", srg)
    end

    @p1 = Project.create!(name: 'Photon OS 3')
    @comp = described_class.create!(project: @p1, version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: @srg1)
    @comp_with_locked_rules = described_class.create!(project: @p1, version: 'Photos OS 3 V1R1', prefix: 'PHOT-03',
                                                      based_on: @srg2)
    @comp_with_locked_rules.rules.update(locked: true)
    @released_comp = described_class.create!(project: @p1, version: 'Phot OS 3 V1R1', prefix: 'PHOS-03',
                                             based_on: @srg1)
    @released_comp.rules.update(locked: true)
    @released_comp.update(released: true)
  end

  after(:each) do
    SecurityRequirementsGuide.destroy_all
    Project.destroy_all
    Component.destroy_all
  end

  describe 'Validations:' do
    subject { @comp }

    it 'should be valid with valid attributes' do
      should be_valid
    end

    it 'should not be valid without a prefix' do
      should_not allow_values(nil, '', '    ').for(:prefix)
    end

    it 'should have a prefix with valid format' do
      # valid formats
      subject.prefix = '1111-AA'
      should be_valid

      subject.prefix = 'AAA1-00'
      should be_valid

      # invalid formats
      subject.prefix = 'AAAA00'
      should_not be_valid

      subject.prefix = ' AAAA-00 '
      should_not be_valid
      expect(subject.errors.full_messages).to include('Prefix must be of the form AAAA-00')
    end
  end

  describe 'Associations: component' do
    subject { @comp }

    it 'should belong to a project' do
      should belong_to(:project).inverse_of(:components)
    end

    it 'should be based on a Security Requirements Guide' do
      should belong_to(:based_on).class_name('SecurityRequirementsGuide')
    end

    it 'can belong to a component' do
      should belong_to(:component).class_name('Component').without_validating_presence.inverse_of(:child_components)
    end

    it 'can have many child components' do
      should have_many(:child_components).class_name('Component').inverse_of(:component)
    end

    it 'can have many user memberships' do
      should have_many(:memberships).inverse_of(:membership)
    end

    it 'can have many additional questions' do
      should have_many(:additional_questions)
    end

    it 'can have many rules' do
      should have_many(:rules).dependent(:destroy)
    end
    it 'can have one component metadata' do
      should have_one(:component_metadata)
    end

    it 'can accept nested attributes for attributes [:rules, :component_metadata, :additional_questions]' do
      should accept_nested_attributes_for(:rules).allow_destroy(true)
      should accept_nested_attributes_for(:component_metadata).allow_destroy(true)
      should accept_nested_attributes_for(:additional_questions).allow_destroy(true)
    end

    # DB index
    it { should have_db_index(:component_id) }
    it { should have_db_index(:project_id) }
  end

  describe 'Release: component' do
    let(:comp) { @comp_with_locked_rules }

    it 'should be releasable if not yet released and all rules are locked' do
      expect(comp.released_was).to be false
      expect(comp.releasable).to be true
    end

    it 'should not be releasable if already released' do
      expect(comp).to be_valid

      comp.update(released: true)

      expect(comp).to be_valid
      expect(comp.released_was).to be true
      expect(comp.releasable).to be false
    end

    it 'should not be releasale if all rules are not locked' do
      expect(comp).to be_valid

      comp.rules.first.update(locked: false)

      expect(comp.releasable).to be false

      comp.update(released: true)
      err = 'Cannot release a component that contains rules that are not yet locked'
      expect(comp.errors.full_messages).to include(err)
    end

    it 'should not be unreleasable when already released' do
      expect(comp).to be_valid
      expect(comp.releasable).to be true

      comp.update(released: true)

      expect(comp).to be_valid

      comp.update(released: false)

      expect(comp.errors.full_messages).to include('Cannot unrelease a released component')
    end
  end

  describe 'Overlay: component' do
    let(:comp) { @comp }
    let(:unreleased_comp) { @comp_with_locked_rules }

    it 'should not overlay a component that has not been released' do
      expect(comp).to be_valid
      expect(unreleased_comp.releasable).to be true

      comp.update(component_id: unreleased_comp.id)

      expect(comp).to_not be_valid
      expect(comp.errors.full_messages).to include('Cannot overlay a component that has not been released')
    end

    it 'should not overlay itself' do
      expect(comp).to be_valid

      comp.update(component_id: comp.id)

      expect(comp).to_not be_valid
      expect(comp.errors.full_messages).to include('Component cannot overlay itself')
    end

    it 'should only overlay a component that has been released and is not self' do
      expect(comp).to be_valid
      expect(unreleased_comp.releasable).to be true

      unreleased_comp.update(released: true)
      comp.update(component_id: unreleased_comp.id)

      expect(comp).to be_valid
    end
  end

  describe 'Create a new component' do
    let(:comp) { @comp }
    let(:srg) { @srg1 }

    context 'when selecting an existing SRG and passing valid attributes: a component' do
      it 'can be created from an existing base SRG' do
        # @comp was created in the setup based on @srg1
        expect(comp).to  be_valid
        # check the rules has been imported
        expect(comp.rules.size).to eq(srg.srg_rules.size)
        expect(srg.srg_rules.pluck(:version)).to include(*comp.rules.pluck(:version))
      end
    end

    # TODO
    # context 'When passing valid attributes and providing an SRG spreadsheet' do

    # it 'can be created from a provided SRG spreadsheet' do
    # end

    # it 'cannot be created from a provided SRG file that's not a spreadsheet' do
    # end
    # end
  end

  describe 'Duplicate a component under the same project' do
    let(:comp) { @released_comp }

    context 'When using the same SRG version/release' do
      let(:duplicate_comp) do
        comp.duplicate(new_name: 'Photos OS 3', new_version: 1, new_release: 2, new_title: 'title',
                       new_description: 'desc')
      end

      it 'can duplicate a component and based on the same SRG version from the original component' do
        expect(duplicate_comp).to  be_valid
        # should have the same number of rules
        expect(comp.rules.size).to eq(duplicate_comp.rules.size)
        # should still be based on the same SRG
        expect(comp.security_requirements_guide_id).to eq(duplicate_comp.security_requirements_guide_id)
        # should belong to the same project
        expect(comp.project_id).to eq(duplicate_comp.project_id)
        # should not be released
        expect(duplicate_comp.released).to be false
        # should have the new name
        expect(duplicate_comp.name).to eq('Photos OS 3')
        # should have the new version
        expect(duplicate_comp.version).to eq(1)
        # should have the new release
        expect(duplicate_comp.release).to eq(2)
        # should have the new title
        expect(duplicate_comp.title).to eq('title')
        # should have the new description
        expect(duplicate_comp.description).to eq('desc')
      end
    end

    context 'When using a different version/release of the original SRG' do
      let(:new_srg) { @srg2 }
      let(:duplicate_comp) do
        comp.duplicate(new_name: 'Photos OS 3', new_version: 1, new_release: 2, new_title: 'title',
                       new_description: 'desc', new_srg_id: new_srg.id)
      end

      it 'can duplicate a component and based on a different version of the SRG from the original component' do
        expect(duplicate_comp).to be_valid
        # should have different based_on
        expect(duplicate_comp.security_requirements_guide_id).to_not eq(comp.security_requirements_guide_id)
        # all rules version should be from the new srg
        expect(new_srg.srg_rules.pluck(:version)).to  include(*duplicate_comp.rules.pluck(:version))
        expect(new_srg.srg_rules.pluck(:id)).to include(*duplicate_comp.rules.pluck(:srg_rule_id))
      end

      it 'orginal component should not change after duplicate operation' do
        expect(comp.security_requirements_guide_id).to eq(@srg1.id)
        expect(comp.rules.size).to eq(@released_comp.rules.size)
      end

      it 'can duplicate a component that has been modified' do
        3.times do
          rule = comp.rules.first.amoeba_dup
          rule.rule_id = nil
          comp.rules.push(rule)
        end
        comp.save!
        comp.rules.last.destroy!
        comp_rules_count = comp.rules.size
        new_comp = comp.duplicate(new_name: 'Test OS 3', new_version: 1, new_release: 2, new_title: 'test title',
                                  new_description: 'test desc', new_srg_id: new_srg.id)

        expect(new_comp).to be_valid
        # should have different based_on
        expect(new_comp.security_requirements_guide_id).to_not eq(comp.security_requirements_guide_id)
        expect(new_comp.security_requirements_guide_id).to eq(new_srg.id)
        # all rules version should be from the new srg
        expect(new_srg.srg_rules.pluck(:version)).to include(*new_comp.rules.pluck(:version))
        expect(new_srg.srg_rules.pluck(:id)).to include(*new_comp.rules.pluck(:srg_rule_id))

        expect(comp.rules.size).to eq(comp_rules_count)
      end
    end
  end
end
