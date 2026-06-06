# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  context 'component creation' do
    it 'can duplicate a component under the same project' do
      components_component.rules.update(locked: true)
      components_component.reload
      components_component.update(released: true)

      p1_c2 = components_component.duplicate(new_name: 'Photon OS 3', new_version: 1, new_release: 2, new_title: 'title',
                                             new_description: 'desc')
      # should have the same number of rules
      expect(components_component.rules.size).to eq(p1_c2.rules.size)
      # should still belong to the same SRG
      expect(components_component.security_requirements_guide_id).to eq(p1_c2.security_requirements_guide_id)
      # should still belong to the same project
      expect(components_component.project_id).to eq(p1_c2.project_id)
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
      components_component.reload
      expect(components_component.rules.size).to eq(components_srg.srg_rules.size)
    end
  end
end
