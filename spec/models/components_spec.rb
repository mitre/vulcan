# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component, type: :model do
  before :each do
    @circular_err = 'Relationship would create a circular dependency among components'
    @duplicate_err = 'already has this component'
    @parent_depth_err = 'Component relationship is too deep due to parent project'
    @child_depth_err = 'Component relationship is too deep due to child project'

    srg_xml = file_fixture('U_Web_Server_V2R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!

    @admin = build(:user)
    @admin.update(admin: true)

    @p1 = Project.create!(name: 'P1')
    @p2 = Project.create!(name: 'P2')
    @p3 = Project.create!(name: 'P3')
    @p4 = Project.create!(name: 'P4')

    @c1 = Project.create!(name: 'C1', prefix: 'AAAA-00', based_on: srg)
    @c2 = Project.create!(name: 'C2', prefix: 'AAAA-00', based_on: srg)
    @c3 = Project.create!(name: 'C3', prefix: 'AAAA-00', based_on: srg)
    @c4 = Project.create!(name: 'C4', prefix: 'AAAA-00', based_on: srg)
    @c5 = Project.create!(name: 'C5', prefix: 'AAAA-00', based_on: srg)

    Component.create!(project: @p1, child_project: @c1)
  end

  context 'enforced component depth of 1' do
    it 'blocks parent depth with P2 => P1' do
      component = Component.new(project: @c1, child_project: @c2)
      component.valid?
      expect(component.errors[:base]).to include(@parent_depth_err)
    end

    it 'blocks child depth with C1 => C2' do
      component = Component.new(project: @p2, child_project: @p1)
      component.valid?
      expect(component.errors[:base]).to include(@child_depth_err)
    end

    it 'Project#available_components are all valid' do
      Component.create(project: @p1, child_project: @c2)
      Component.create(project: @p1, child_project: @c2)
      Component.create(project: @p2, child_project: @c2)
      Component.create(project: @p2, child_project: @c4)

      Project.all.each do |project|
        project.current_user = @admin
        project.available_components.each do |component|
          expect(component.valid?).to eq(true)
        end
      end
    end

    it 'Projects.all - Project#available_components are all NOT valid' do
      Component.create(project: @p1, child_project: @c2)
      Component.create(project: @p1, child_project: @c2)
      Component.create(project: @p2, child_project: @c2)
      Component.create(project: @p2, child_project: @c4)

      Project.all.each do |project|
        project.current_user = @admin
        Project.where.not(id: project.available_components.map(&:child_project_id)).each do |child_project|
          component = Component.new(project: project, child_project: child_project)
          expect(component.valid?).to eq(false)
        end
      end
    end
  end

  context 'no duplicates allowed' do
    it 'blocks P1 => C1' do
      component = Component.new(project: @p1, child_project: @c1)
      component.valid?
      expect(component.errors[:project_id]).to include(@duplicate_err)
    end

    # Commented out tests can be used if component depth constraint is lifted
    # it 'blocks P5 => P7' do
    #   component = Component.new(project: @p5, child_project: @p7)
    #   component.valid?
    #   expect(component.errors[:project_id]).to include(@duplicate_err)
    # end
  end

  # Commented out tests can be used if component depth constraint is lifted
  context 'no circular dependencies allowed' do
    it 'blocks P1 => P1' do
      component = Component.new(project: @p1, child_project: @p1)
      component.valid?
      expect(component.errors[:base]).to include(@circular_err)
    end

    it 'blocks C1 => P1' do
      component = Component.new(project: @c1, child_project: @p1)
      component.valid?
      expect(component.errors[:base]).to include(@circular_err)
    end

    # it 'blocks P8 => P4' do
    #   component = Component.new(project: @p8, child_project: @p4)
    #   component.valid?
    #   expect(component.errors[:base]).to include(@circular_err)
    # end

    # it 'blocks P8 => P2' do
    #   component = Component.new(project: @p8, child_project: @p2)
    #   component.valid?
    #   expect(component.errors[:base]).to include(@circular_err)
    # end

    # it 'blocks P5 => P8' do
    #   component = Component.new(project: @p5, child_project: @p8)
    #   component.valid?
    #   expect(component.errors[:base]).to include(@circular_err)
    # end

    # it 'blocks P6 => P1' do
    #   component = Component.new(project: @p6, child_project: @p1)
    #   component.valid?
    #   expect(component.errors[:base]).to include(@circular_err)
    # end
  end
end
