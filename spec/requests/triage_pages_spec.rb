# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: the full-page triage views (/components/:id/triage and
# /projects/:id/triage) are HTML-only — the Vue app then fetches data
# from the dedicated JSON endpoints (/components/:id/comments and
# /projects/:id/comments). A client requesting these pages with an
# Accept: application/json header today blows up with a missing
# template error; explicit format.html scoping prevents that.
#
# Authorization mirrors the per-component / per-project read scope
# already enforced by the API endpoints.
RSpec.describe 'Triage page HTML responses' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:viewer) { create(:user) }
  let_it_be(:outsider) { create(:user) }

  before_all do
    Membership.find_or_create_by!(user: viewer, membership: project) { |m| m.role = 'viewer' }
  end

  before { Rails.application.reload_routes! }

  describe 'GET /components/:id/triage' do
    context 'as a project member' do
      before { sign_in viewer }

      it 'renders the HTML page' do
        get "/components/#{component.id}/triage"
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/html')
      end

      it 'returns 406 when the client requests JSON (no JSON template exists)' do
        get "/components/#{component.id}/triage", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:not_acceptable)
      end
    end

    context 'as a non-member of an unreleased component' do
      before { sign_in outsider }

      # A hidden project is concealed from non-members: the denial answers a
      # bare 404 identical to a true miss, on HTML as on JSON — no redirect
      # that would reveal the resource exists.
      it 'conceals the component (hidden project → 404)' do
        get "/components/#{component.id}/triage"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /projects/:id/triage' do
    context 'as a project member' do
      before { sign_in viewer }

      it 'renders the HTML page' do
        get "/projects/#{project.id}/triage"
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/html')
      end

      it 'returns 406 when the client requests JSON (no JSON template exists)' do
        get "/projects/#{project.id}/triage", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:not_acceptable)
      end
    end

    context 'as a non-member' do
      before { sign_in outsider }

      it 'conceals the project (hidden → 404)' do
        get "/projects/#{project.id}/triage"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
