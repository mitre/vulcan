# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rule do
  include_context 'with auditing'

  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }

  let(:child) { component.rules[0] }
  let(:parent) { component.rules[1] }

  describe '#apply_nesting_status!' do
    it 'sets status to ADNM' do
      child.update!(status: 'Applicable - Configurable')
      child.apply_nesting_status!(parent)
      expect(child.reload.status).to eq('Applicable - Does Not Meet')
    end

    it 'populates mitigation with canonical DISA format' do
      child.apply_nesting_status!(parent)
      drd = child.disa_rule_descriptions.first
      expect(drd.mitigations).to include("fully mitigated by #{component.prefix}-#{parent.rule_id}")
    end

    it 'populates status_justification referencing parent' do
      child.reload
      child.apply_nesting_status!(parent)
      expect(child.reload.status_justification).to include("#{component.prefix}-#{parent.rule_id}")
    end

    it 'does NOT clear check/fix content' do
      child.update!(fixtext: 'My custom fix')
      child.apply_nesting_status!(parent)
      expect(child.reload.fixtext).to eq('My custom fix')
    end

    it 'records original status in audit comment' do
      child.update!(status: 'Applicable - Configurable')
      child.apply_nesting_status!(parent)
      adnm_audit = child.audits.where("comment LIKE 'Auto-set ADNM:%'").last
      expect(adnm_audit).to be_present
      expect(adnm_audit.comment).to include('was: Applicable - Configurable')
    end
  end

  describe '#revert_nesting_status!' do
    before do
      child.update!(status: 'Applicable - Configurable')
      child.apply_nesting_status!(parent)
    end

    it 'restores original pre-nesting status from audit trail' do
      child.revert_nesting_status!
      expect(child.reload.status).to eq('Applicable - Configurable')
    end

    it 'clears mitigation and status_justification' do
      child.revert_nesting_status!
      child.reload
      expect(child.status_justification).to be_blank
      expect(child.disa_rule_descriptions.first&.mitigations).to be_blank
    end

    it 'falls back to NYD when no nesting audit exists' do
      child.audits.destroy_all
      child.revert_nesting_status!
      expect(child.reload.status).to eq('Not Yet Determined')
    end

    it 'preserves check/fix content through full cycle' do
      child_with_content = component.rules[2]
      child_with_content.update!(fixtext: 'Hours of work', status: 'Applicable - Configurable')
      child_with_content.apply_nesting_status!(parent)
      child_with_content.revert_nesting_status!
      expect(child_with_content.reload.fixtext).to eq('Hours of work')
      expect(child_with_content.status).to eq('Applicable - Configurable')
    end
  end
end
