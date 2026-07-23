# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (multi-parent creation API): component creation accepts the
# full declared source-SRG set plus the primary designation
# (security_requirements_guide_id IS the primary), lands every source as a
# join row through the parent-set reconciliation, and imports requirements
# from ALL declared parents through the one import machinery — full union
# by default, selective when a requirement filter is supplied. Both kinds.
RSpec.describe 'Component creation with declared sources' do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:membership) { Membership.create!(user: admin, membership: project, role: 'admin') }

  let_it_be(:core_a) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-OS-API', version: 'V1R1')
  end
  let_it_be(:core_a_rows) do
    %w[SRG-OS-000001 SRG-OS-000002].map do |version|
      create(:srg_rule, security_requirements_guide: core_a, version: version)
    end
  end
  let_it_be(:core_b) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-APP-API', version: 'V1R1')
  end
  let_it_be(:core_b_rows) do
    [create(:srg_rule, security_requirements_guide: core_b, version: 'SRG-APP-000101')]
  end
  # Full-XML derived SRG — the stig-kind import path parses the benchmark.
  let_it_be(:derived_a) { create(:security_requirements_guide) }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  def created_component(name)
    Component.find_by!(project: project, name: name)
  end

  describe 'srg-kind multi-source creation' do
    it 'creates the component with all join rows, the designated primary, and union-imported requirements' do
      post "/projects/#{project.id}/components",
           params: { component: { name: 'Dual-home SRG', prefix: 'DUAL-00', title: 'Dual-home SRG',
                                  version: 1, release: 1, document_type: 'srg',
                                  security_requirements_guide_id: core_a.id,
                                  declared_source_srg_ids: [core_a.id, core_b.id] } }

      expect(response).to have_http_status(:ok)
      component = created_component('Dual-home SRG')
      expect(component.source_srgs).to contain_exactly(core_a, core_b)
      expect(component.security_requirements_guide_id).to eq(core_a.id)

      rows = component.authored_srg_rules
      expect(rows.map(&:version)).to match_array(%w[SRG-OS-000001 SRG-OS-000002 SRG-APP-000101])
      expect(rows.map(&:derived_from_srg_rule_id))
        .to match_array((core_a_rows + core_b_rows).map(&:id))
    end

    it 'honors selective mode through the requirement filter' do
      post "/projects/#{project.id}/components",
           params: { component: { name: 'Selective SRG', prefix: 'SELE-00', title: 'Selective SRG',
                                  version: 1, release: 1, document_type: 'srg',
                                  security_requirements_guide_id: core_a.id,
                                  declared_source_srg_ids: [core_a.id, core_b.id],
                                  requirement_selections: {
                                    core_a.id => ['SRG-OS-000002'],
                                    core_b.id => ['SRG-APP-000101']
                                  } } }

      expect(response).to have_http_status(:ok)
      component = created_component('Selective SRG')
      expect(component.source_srgs).to contain_exactly(core_a, core_b)
      expect(component.authored_srg_rules.pluck(:version))
        .to match_array(%w[SRG-OS-000002 SRG-APP-000101])
    end

    it 'rejects an ineligible declared source with a 422 toast and creates nothing' do
      post "/projects/#{project.id}/components",
           params: { component: { name: 'Bad-source SRG', prefix: 'BADS-00', title: 'Bad-source SRG',
                                  version: 1, release: 1, document_type: 'srg',
                                  security_requirements_guide_id: core_a.id,
                                  declared_source_srg_ids: [core_a.id, derived_a.id] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join).to include('must be a core SRG')
      expect(Component.find_by(project: project, name: 'Bad-source SRG')).to be_nil
    end
  end

  describe 'stig-kind multi-source creation' do
    let_it_be(:derived_b) { create(:security_requirements_guide) }

    it 'creates the component with both join rows and one Rule sequence across parents' do
      post "/projects/#{project.id}/components",
           params: { component: { name: 'Dual-source STIG', prefix: 'DSTG-00', title: 'Dual-source STIG',
                                  version: 1, release: 1,
                                  security_requirements_guide_id: derived_a.id,
                                  declared_source_srg_ids: [derived_a.id, derived_b.id] } }

      expect(response).to have_http_status(:ok)
      component = created_component('Dual-source STIG')
      expect(component.source_srgs).to contain_exactly(derived_a, derived_b)
      expect(component.security_requirements_guide_id).to eq(derived_a.id)

      rules = component.rules
      expect(rules.size).to eq(derived_a.srg_rules.count + derived_b.srg_rules.count)
      expect(rules.map { |rule| rule.rule_id.to_i }.sort).to eq((1..rules.size).to_a)
    end
  end

  describe 'single-source creation (existing contract unchanged)' do
    it 'still creates a stig component from security_requirements_guide_id alone' do
      post "/projects/#{project.id}/components",
           params: { component: { name: 'Classic STIG', prefix: 'CLAS-00', title: 'Classic STIG',
                                  version: 1, release: 1,
                                  security_requirements_guide_id: derived_a.id } }

      expect(response).to have_http_status(:ok)
      component = created_component('Classic STIG')
      expect(component.source_srgs).to contain_exactly(derived_a)
      expect(component.rules.count).to eq(derived_a.srg_rules.count)
    end
  end
end
