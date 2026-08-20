# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: create(:component) must ALWAYS yield a component whose
# based_on is a persisted SecurityRequirementsGuide and whose
# security_requirements_guide_id references an existing row — including
# when the component is created inside let_it_be under the global
# refind: true configuration, and including when that based_on is then
# copied to another component. The factory's shared-SRG reuse
# (one ~500ms XML import for the whole run, not one per component) must
# keep working; these specs guard correctness of that reuse, not replace it.
RSpec.describe 'component factory based_on persistence' do
  describe 'inside let_it_be (global refind: true)' do
    let_it_be(:component) { create(:component, :skip_rules) }

    it 'yields a persisted based_on' do
      expect(component.based_on).to be_persisted
    end

    it 'yields a based_on with a present id' do
      expect(component.based_on&.id).to be_present
    end

    it 'references an existing SRG row (not dangling)' do
      expect(SecurityRequirementsGuide.exists?(component.security_requirements_guide_id)).to be true
    end

    it 'supports copying based_on to another component without a dangling FK' do
      copy = create(:component, :skip_rules, based_on: component.based_on)
      expect(copy.security_requirements_guide_id).to be_present
      expect(SecurityRequirementsGuide.exists?(copy.security_requirements_guide_id)).to be true
    end
  end
end
