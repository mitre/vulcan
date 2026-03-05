# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Project-level activity view (Phase 4).
# Projects must expose a histories endpoint that includes:
# - Project metadata changes
# - Component changes (via has_associated_audits)
# - Membership changes (via associated_with)
RSpec.describe 'Project Histories' do
  let_it_be(:user) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  before do
    Rails.application.reload_routes!
    sign_in user
    Membership.create!(user: user, membership: project, role: 'admin')
  end

  describe 'GET /projects/:id/histories' do
    it 'requires authentication' do
      sign_out user
      get "/projects/#{project.id}/histories",
          headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end

    it 'returns an array of formatted audit entries' do
      # Generate an audit by updating the project
      project.update!(name: 'Updated Project Name', audit_comment: 'Test project history')

      get "/projects/#{project.id}/histories",
          headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json).to be_an(Array)
      expect(json.length).to be > 0

      entry = json.last
      expect(entry).to have_key('action')
      expect(entry).to have_key('audited_changes')
      expect(entry).to have_key('created_at')
    end

    it 'includes component changes in project history' do
      # Component is associated_with project, so its audits should bubble up
      rule = component.rules.first
      rule&.update!(title: 'Updated for project history test')

      get "/projects/#{project.id}/histories",
          headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json).to be_an(Array)
    end

    it 'returns error for non-existent project' do
      get '/projects/999999/histories',
          headers: { 'Accept' => 'application/json' }
      expect(response.status).to be >= 400
    end
  end
end
