# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
#
# 1. GET /components/:id/settings is the admin-only configuration page —
#    Identity / PoC / Public Comment Period sections live here. Renders
#    HTML that mounts the ComponentSettingsPage Vue app.
# 2. Authorization: project-admin or higher. Authors and reviewers cannot
#    reach this page. Non-members get redirected.
# 3. The action exposes the same component blueprint payload that the
#    component editor uses (so the page has access to all editable fields)
#    plus the comment_phase / comment_period_* fields needed for the
#    Public Comment Period section.
RSpec.describe 'GET /components/:id/settings' do
  # Ensure none of these users are auto-promoted to Vulcan-wide admin via
  # the first-user-admin path — we want the auth checks to be evaluated
  # purely on project/component role.
  let_it_be(:seed_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  before do
    Rails.application.reload_routes!
  end

  context 'as a project admin' do
    let(:admin_user) { create(:user, admin: false) }

    before do
      Membership.create!(user: admin_user, membership: project, role: 'admin')
      sign_in admin_user
    end

    it 'returns the settings page successfully' do
      get "/components/#{component.id}/settings"
      expect(response).to have_http_status(:success)
    end

    it 'renders HTML (not JSON) — this is a full page' do
      get "/components/#{component.id}/settings"
      expect(response.content_type).to include('text/html')
    end
  end

  context 'as a project author (not admin)' do
    let(:author_user) { create(:user, admin: false) }

    before do
      Membership.create!(user: author_user, membership: project, role: 'author')
      sign_in author_user
    end

    it 'is denied — settings is admin-only' do
      get "/components/#{component.id}/settings"
      # not_authorized handler redirects HTML to root_path
      expect(response).to redirect_to(root_path)
    end
  end

  context 'as a non-member' do
    let(:outsider) { create(:user, admin: false) }

    before { sign_in outsider }

    it 'is denied' do
      get "/components/#{component.id}/settings"
      expect(response).to redirect_to(root_path)
    end
  end

  context 'when not signed in' do
    it 'redirects to sign-in' do
      get "/components/#{component.id}/settings"
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
