# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'rake fix_adnm_status' do
  before(:all) do
    Rails.application.load_tasks
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:parent_component) { create(:component, project: project) }
  let_it_be(:child_component) { create(:component, project: project) }

  let(:parent_rule) { parent_component.rules.first }
  let(:child_rule) { child_component.rules.first }

  before do
    Rake::Task['fix_adnm_status'].reenable
    child_rule.satisfied_by << parent_rule unless child_rule.satisfied_by.include?(parent_rule)
    child_rule.update_columns(status: 'Not Yet Determined', status_justification: nil)
  end

  describe 'DRY_RUN=1' do
    it 'reports rules needing fix without changing them' do
      ClimateControl.modify(DRY_RUN: '1') do
        expect { Rake::Task['fix_adnm_status'].invoke }
          .to output(/Found 1 rules needing ADNM/).to_stdout
      end

      child_rule.reload
      expect(child_rule.status).to eq('Not Yet Determined')
    end
  end

  describe 'live run' do
    it 'sets ADNM status on rules with satisfied_by' do
      expect { Rake::Task['fix_adnm_status'].invoke }
        .to output(/→ ADNM/).to_stdout

      child_rule.reload
      expect(child_rule.status).to eq('Applicable - Does Not Meet')
    end

    it 'sets status_justification with parent label' do
      Rake::Task['fix_adnm_status'].invoke

      child_rule.reload
      expect(child_rule.status_justification).to include(parent_component.prefix)
      expect(child_rule.status_justification).to include(parent_rule.rule_id)
    end

    it 'sets mitigations on disa_rule_description' do
      Rake::Task['fix_adnm_status'].invoke

      child_rule.reload
      drd = child_rule.disa_rule_descriptions.first
      expect(drd).to be_present
      expect(drd.mitigations).to include(parent_component.prefix)
      expect(drd.mitigations).to include('fully mitigated')
    end

    it 'is idempotent — second run finds zero rules' do
      Rake::Task['fix_adnm_status'].invoke
      Rake::Task['fix_adnm_status'].reenable

      expect { Rake::Task['fix_adnm_status'].invoke }
        .to output(/Found 0 rules/).to_stdout
    end
  end

  describe 'COMPONENT_ID filter' do
    it 'scopes to a single component' do
      ClimateControl.modify(COMPONENT_ID: child_component.id.to_s) do
        expect { Rake::Task['fix_adnm_status'].invoke }
          .to output(/Found 1 rules/).to_stdout
      end
    end
  end

  describe 'LIMIT filter' do
    it 'limits the number of rules processed' do
      ClimateControl.modify(LIMIT: '1') do
        expect { Rake::Task['fix_adnm_status'].invoke }
          .to output(/Fixed: 1/).to_stdout
      end
    end
  end

  describe 'already-ADNM rules' do
    before do
      child_rule.update_columns(status: 'Applicable - Does Not Meet')
    end

    it 'finds zero rules when all are already ADNM' do
      expect { Rake::Task['fix_adnm_status'].invoke }
        .to output(/Found 0 rules/).to_stdout
    end
  end
end
