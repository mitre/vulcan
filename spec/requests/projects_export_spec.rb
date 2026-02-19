# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: Project-level CSV export must work alongside existing Excel,
# XCCDF, and InSpec exports. Gap 6 in export-requirements.md — the
# project controller's allowlist omits :csv, so requesting CSV returns 400.
# ==========================================================================
RSpec.describe 'Project Exports' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  before do
    Rails.application.reload_routes!
    sign_in user
    Membership.create!(user: user, membership: project, role: 'viewer')
  end

  describe 'GET /projects/:id/export/csv' do
    it 'exports CSV successfully' do
      get "/projects/#{project.id}/export/csv",
          headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('text/csv')
    end

    it 'includes project name in filename' do
      get "/projects/#{project.id}/export/csv",
          headers: { 'Accept' => 'text/html' }
      expect(response.headers['Content-Disposition']).to include(project.name)
    end
  end

  describe 'GET /projects/:id/export/:type (existing types still work)' do
    it 'rejects unsupported export types' do
      get "/projects/#{project.id}/export/banana",
          headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
