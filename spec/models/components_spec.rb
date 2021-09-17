# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component, type: :model do
  before :each do
    @circular_err = 'Relationship would create a circular dependency among components'
    @duplicate_err = 'already has this component'

    @p1 = Project.create(name: 'P1')
    @p2 = Project.create(name: 'P2')
    @p3 = Project.create(name: 'P3')
    @p4 = Project.create(name: 'P4')
    @p5 = Project.create(name: 'P5')
    @p6 = Project.create(name: 'P6')
    @p7 = Project.create(name: 'P7')
    @p8 = Project.create(name: 'P8')

    # Representation of the created graph
    # Note that not all relationships are "downward"
    # - P8 => P5
    # - P8 => P7
    #
    #     P1      P2
    #       \    /   \
    #         P3      P4
    #       /   \    /
    #     P5      P6
    #    /   \  /
    # P7 ---- P8
    Component.create(project: @p1, child_project: @p3)
    Component.create(project: @p2, child_project: @p3)
    Component.create(project: @p2, child_project: @p4)
    Component.create(project: @p3, child_project: @p5)
    Component.create(project: @p3, child_project: @p6)
    Component.create(project: @p4, child_project: @p6)
    Component.create(project: @p5, child_project: @p7)
    Component.create(project: @p6, child_project: @p8)
    Component.create(project: @p8, child_project: @p5)
    Component.create(project: @p8, child_project: @p7)
  end

  context 'no duplicates allowed' do
    it 'blocks P1 => P3' do
      component = Component.new(project: @p1, child_project: @p3)
      component.valid?
      expect(component.errors[:project_id]).to include(@duplicate_err)
    end

    it 'blocks P5 => P7' do
      component = Component.new(project: @p5, child_project: @p7)
      component.valid?
      expect(component.errors[:project_id]).to include(@duplicate_err)
    end
  end

  context 'no circular dependencies allowed' do
    it 'blocks P1 => P1' do
      component = Component.new(project: @p1, child_project: @p1)
      component.valid?
      expect(component.errors[:base]).to include(@circular_err)
    end

    it 'blocks P8 => P4' do
      component = Component.new(project: @p8, child_project: @p4)
      component.valid?
      expect(component.errors[:base]).to include(@circular_err)
    end

    it 'blocks P8 => P2' do
      component = Component.new(project: @p8, child_project: @p2)
      component.valid?
      expect(component.errors[:base]).to include(@circular_err)
    end

    it 'blocks P5 => P8' do
      component = Component.new(project: @p5, child_project: @p8)
      component.valid?
      expect(component.errors[:base]).to include(@circular_err)
    end

    it 'blocks P6 => P1' do
      component = Component.new(project: @p6, child_project: @p1)
      component.valid?
      expect(component.errors[:base]).to include(@circular_err)
    end
  end
end
