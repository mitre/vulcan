# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component authorization' do
  let_it_be(:seed_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  let_it_be(:admin_user) { create(:user, admin: false) }
  let_it_be(:author_user) { create(:user, admin: false) }
  let_it_be(:viewer_user) { create(:user, admin: false) }
  let_it_be(:outsider) { create(:user, admin: false) }

  let_it_be(:admin_membership) { Membership.create!(user: admin_user, membership: project, role: 'admin') }
  let_it_be(:author_membership) { Membership.create!(user: author_user, membership: project, role: 'author') }
  let_it_be(:viewer_membership) { Membership.create!(user: viewer_user, membership: project, role: 'viewer') }

  let(:json_headers) { { 'Accept' => 'application/json' } }

  before { Rails.application.reload_routes! }

  describe 'POST /components (create) — authorize_admin_project' do
    let(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
    let(:create_params) do
      {
        project_id: project.id,
        component: {
          name: 'Auth Dup Test', version: 1, release: 1, prefix: 'AUTHDUP',
          project_id: project.id, id: component.id, duplicate: true
        }
      }
    end

    it 'is not rejected as project admin (auth passes)' do
      sign_in admin_user
      post "/projects/#{project.id}/components", params: create_params
      expect(response).not_to have_http_status(:forbidden)
      expect(response).not_to redirect_to(root_path)
    end

    it 'rejects project author' do
      sign_in author_user
      post "/projects/#{project.id}/components", params: create_params
      expect(response).to redirect_to(root_path)
    end

    it 'redirects unauthenticated to sign-in' do
      post "/projects/#{project.id}/components", params: create_params
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /components/:id/triage — authorize_component_access' do
    it 'succeeds as project viewer (minimum role)' do
      sign_in viewer_user
      get "/components/#{component.id}/triage"
      expect(response).to have_http_status(:success)
    end

    it 'rejects non-member' do
      sign_in outsider
      get "/components/#{component.id}/triage"
      expect(response).to redirect_to(root_path)
    end

    it 'redirects unauthenticated to sign-in' do
      get "/components/#{component.id}/triage"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /components/:id/comments — authorize_component_access' do
    it 'succeeds as project viewer' do
      sign_in viewer_user
      get "/components/#{component.id}/comments", headers: json_headers
      expect(response).to have_http_status(:success)
    end

    it 'rejects non-member (JSON → 403)' do
      sign_in outsider
      get "/components/#{component.id}/comments", headers: json_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects unauthenticated to sign-in' do
      get "/components/#{component.id}/comments", headers: json_headers
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end
  end

  describe 'GET /search/components — authorize_logged_in' do
    it 'succeeds when logged in (any user)' do
      sign_in outsider
      get '/search/components', params: { query: 'test' }, headers: json_headers
      expect(response).to have_http_status(:success)
    end

    it 'redirects unauthenticated' do
      get '/search/components', params: { query: 'test' }, headers: json_headers
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end
  end

  describe 'GET /components/:id/related — authorize_logged_in' do
    it 'succeeds for any logged-in user' do
      sign_in outsider
      get "/components/#{component.id}/related", headers: json_headers
      expect(response).to have_http_status(:success)
        .or have_http_status(:not_found)
    end

    it 'redirects unauthenticated' do
      get "/components/#{component.id}/related", headers: json_headers
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end
  end

  describe 'GET /api/components/compare — authorize_compare_access' do
    let_it_be(:other_component) { create(:component, project: project) }

    it 'succeeds as project viewer' do
      sign_in viewer_user
      get '/api/components/compare',
          params: { base_id: component.id, diff_id: other_component.id },
          headers: json_headers
      expect(response).to have_http_status(:success)
    end

    it 'rejects non-member (JSON → 403)' do
      sign_in outsider
      get '/api/components/compare',
          params: { base_id: component.id, diff_id: other_component.id },
          headers: json_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects unauthenticated' do
      get '/api/components/compare',
          params: { base_id: component.id, diff_id: other_component.id },
          headers: json_headers
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end
  end

  describe 'GET /components/history — authorize_viewer_project' do
    it 'succeeds as project viewer' do
      sign_in viewer_user
      get '/components/history',
          params: { project_id: project.id, name: component.name },
          headers: json_headers
      expect(response).to have_http_status(:success)
    end

    it 'rejects non-member (JSON → 403)' do
      sign_in outsider
      get '/components/history',
          params: { project_id: project.id, name: component.name },
          headers: json_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects unauthenticated' do
      get '/components/history',
          params: { project_id: project.id, name: component.name },
          headers: json_headers
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end
  end

  describe 'POST /components/:id/find — authorize_component_access' do
    it 'succeeds as project viewer' do
      sign_in viewer_user
      post "/components/#{component.id}/find", params: { find: 'test' }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'rejects non-member (JSON → 403)' do
      sign_in outsider
      post "/components/#{component.id}/find", params: { find: 'test' }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects unauthenticated' do
      post "/components/#{component.id}/find", params: { find: 'test' }, as: :json
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end
  end

  describe 'GET /components/:id/settings — authorize_admin_component' do
    it 'succeeds as project admin' do
      sign_in admin_user
      get "/components/#{component.id}/settings"
      expect(response).to have_http_status(:success)
    end

    it 'rejects project author (HTML → redirect)' do
      sign_in author_user
      get "/components/#{component.id}/settings"
      expect(response).to redirect_to(root_path)
    end

    it 'redirects unauthenticated to sign-in' do
      get "/components/#{component.id}/settings"
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
