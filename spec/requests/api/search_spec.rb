# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Search' do
  # Requirements:
  # - GET /api/search/global returns JSON search results
  # - Requires authentication (returns 401 if not logged in)
  # - Searches projects, components, rules
  # - Only returns results user has access to (via membership)
  # - Respects limit parameter (default 5, max 20)
  # - Returns empty for queries < 2 chars

  before do
    Rails.application.reload_routes!
  end

  # Create admin_user FIRST to prevent first-user-admin promotion
  let!(:admin_user) { create(:user, admin: true) }
  let(:user) { create(:user) }

  # Create test data
  # Note: Set visibility to 'hidden' for project2 so it only appears via membership
  # (default visibility is 'discoverable' which would show in search)
  let!(:project1) { create(:project, name: 'Security Baseline Project') }
  let!(:project2) { create(:project, name: 'Another Secret Project', visibility: :hidden) }

  # Components automatically get rules from the SRG via based_on
  let!(:srg) { create(:security_requirements_guide) }
  let!(:component1) { create(:component, project: project1, name: 'Web Server Component', prefix: 'WEBS-01', based_on: srg) }
  let!(:component2) { create(:component, project: project2, name: 'Database Component', prefix: 'DBAS-01', based_on: srg) }

  # Give user access to project1 only (not project2)
  before do
    Membership.create!(membership: project1, user: user, role: 'viewer')
  end

  describe 'GET /api/search/global' do
    context 'when not authenticated' do
      it 'returns 401 Unauthorized' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      before { sign_in user }

      it 'returns empty results for short queries' do
        get '/api/search/global', params: { q: 'a' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects']).to eq([])
        expect(json['components']).to eq([])
        expect(json['rules']).to eq([])
      end

      it 'searches projects by name' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].length).to eq(1)
        expect(json['projects'][0]['name']).to eq('Security Baseline Project')
      end

      it 'only returns projects user has access to' do
        get '/api/search/global', params: { q: 'Another' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # User doesn't have access to project2 (it's hidden and no membership)
        expect(json['projects']).to eq([])
      end

      it 'searches components by name' do
        get '/api/search/global', params: { q: 'Web Server' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['components'].length).to eq(1)
        expect(json['components'][0]['name']).to eq('Web Server Component')
      end

      it 'searches components by prefix' do
        get '/api/search/global', params: { q: 'WEBS' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['components'].length).to eq(1)
        expect(json['components'][0]['name']).to eq('Web Server Component')
      end

      it 'only returns components from accessible projects' do
        get '/api/search/global', params: { q: 'Database' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # component2 belongs to project2 which user doesn't have access to
        expect(json['components']).to eq([])
      end

      it 'respects limit parameter' do
        # Create more projects for the user
        5.times do |i|
          proj = create(:project, name: "Test Searchable Project #{i}")
          Membership.create!(membership: proj, user: user, role: 'viewer')
        end

        get '/api/search/global', params: { q: 'Test', limit: 3 }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].length).to be <= 3
      end

      it 'returns project metadata' do
        get '/api/search/global', params: { q: 'Security' }

        json = response.parsed_body
        project = json['projects'][0]
        expect(project).to have_key('id')
        expect(project).to have_key('name')
        expect(project).to have_key('description')
        expect(project).to have_key('components_count')
      end

      it 'returns component metadata' do
        get '/api/search/global', params: { q: 'Web' }

        json = response.parsed_body
        component = json['components'][0]
        expect(component).to have_key('id')
        expect(component).to have_key('name')
        expect(component).to have_key('version')
        expect(component).to have_key('release')
        expect(component).to have_key('project_id')
        expect(component).to have_key('project_name')
      end
    end

    context 'rules search' do
      before { sign_in user }

      let!(:rule1) do
        rule = component1.rules.first
        rule.update!(
          title: 'Xylophone Configuration Requirements',
          fixtext: 'Configure xylophone to enforce strict policy'
        )
        rule
      end

      it 'searches rules by title' do
        get '/api/search/global', params: { q: 'Xylophone' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['rules'].length).to be >= 1
        expect(json['rules'][0]['title']).to eq('Xylophone Configuration Requirements')
      end

      it 'only returns rules from accessible components' do
        # Update a rule in component2 (which user doesn't have access to)
        rule2 = component2.rules.first
        rule2.update!(title: 'Platypus Secret Configuration')

        get '/api/search/global', params: { q: 'Platypus' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # User doesn't have access to component2's rules
        expect(json['rules']).to eq([])
      end
    end
  end
end
