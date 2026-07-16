# frozen_string_literal: true

require 'rails_helper'

# Benchmark stats endpoints for the SPA's SRG/STIG pages: rule counts and
# severity breakdowns as SQL aggregates, plus (SRGs only) the reverse lookup
# of which components are based on the SRG — scoped to components the caller
# can actually see (member projects or released), so usage never leaks
# across projects.
RSpec.describe 'Benchmark stats' do
  let_it_be(:existing_admin) { create(:user, admin: true) } # -- side effect: prevents first-user-admin promotion
  let_it_be(:user) { create(:user) }

  let_it_be(:srg) { create(:security_requirements_guide, :skip_rules) }
  let_it_be(:srg_rules) do
    [
      create(:srg_rule, security_requirements_guide: srg, rule_severity: 'high'),
      create(:srg_rule, security_requirements_guide: srg, rule_severity: 'high'),
      create(:srg_rule, security_requirements_guide: srg, rule_severity: 'medium'),
      create(:srg_rule, security_requirements_guide: srg, rule_severity: 'medium'),
      create(:srg_rule, security_requirements_guide: srg, rule_severity: 'medium'),
      create(:srg_rule, security_requirements_guide: srg, rule_severity: 'low')
    ]
  end

  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/srgs/:id/stats' do
    let_it_be(:member_project) { create(:project, name: 'Member Project', visibility: :hidden) }
    let_it_be(:membership) { create(:membership, user: user, membership: member_project) }
    let_it_be(:hidden_project) { create(:project, name: 'Hidden Project', visibility: :hidden) }

    let_it_be(:member_component) do
      create(:component, :skip_rules, based_on: srg, project: member_project,
                                      prefix: 'MEMB-01', name: 'Member Component')
    end
    let_it_be(:released_foreign_component) do
      create(:component, :skip_rules, :released_component, based_on: srg, project: hidden_project,
                                                           prefix: 'RELF-01', name: 'Released Foreign Component')
    end
    let_it_be(:hidden_foreign_component) do
      create(:component, :skip_rules, based_on: srg, project: hidden_project,
                                      prefix: 'HIDD-01', name: 'Hidden Foreign Component')
    end

    it 'requires authentication (usage exposes project data)' do
      get "/api/srgs/#{srg.id}/stats"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#not_authenticated')
    end

    it 'returns rule count and severity breakdown as exact values' do
      sign_in user

      get "/api/srgs/#{srg.id}/stats"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['rule_count']).to eq(6)
      expect(body['severity_counts']).to eq('high' => 2, 'medium' => 3, 'low' => 1)
    end

    it 'lists only caller-visible components in usage — member projects and released' do
      sign_in user

      get "/api/srgs/#{srg.id}/stats"

      usage = response.parsed_body['usage']
      expect(usage['count']).to eq(2)
      expect(usage['components']).to contain_exactly(
        { 'id' => member_component.id, 'name' => 'Member Component',
          'project_id' => member_project.id, 'project_name' => 'Member Project' },
        { 'id' => released_foreign_component.id, 'name' => 'Released Foreign Component',
          'project_id' => hidden_project.id, 'project_name' => 'Hidden Project' }
      )
    end

    it 'never leaks unreleased components from projects the caller cannot see' do
      sign_in user

      get "/api/srgs/#{srg.id}/stats"

      ids = response.parsed_body['usage']['components'].pluck('id')
      expect(ids).not_to include(hidden_foreign_component.id)
    end

    it 'shows all usage to admins (available_projects = all)' do
      sign_in existing_admin

      get "/api/srgs/#{srg.id}/stats"

      expect(response.parsed_body['usage']['count']).to eq(3)
    end

    it 'returns 404 for an unknown SRG' do
      sign_in user

      get '/api/srgs/0/stats'

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#not_found')
    end
  end

  describe 'GET /api/stigs/:id/stats' do
    let_it_be(:stig) { create(:stig, :skip_rules) }
    let_it_be(:stig_rules) do
      [
        create(:stig_rule, stig: stig, rule_severity: 'high'),
        create(:stig_rule, stig: stig, rule_severity: 'medium'),
        create(:stig_rule, stig: stig, rule_severity: 'medium'),
        create(:stig_rule, stig: stig, rule_severity: 'low'),
        create(:stig_rule, stig: stig, rule_severity: 'low'),
        create(:stig_rule, stig: stig, rule_severity: 'low')
      ]
    end

    it 'returns rule count and severity breakdown without authentication (public reference data)' do
      get "/api/stigs/#{stig.id}/stats"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['rule_count']).to eq(6)
      expect(body['severity_counts']).to eq('high' => 1, 'medium' => 2, 'low' => 3)
      expect(body).not_to have_key('usage')
    end

    it 'returns 404 for an unknown STIG' do
      get '/api/stigs/0/stats'

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#not_found')
    end
  end
end
