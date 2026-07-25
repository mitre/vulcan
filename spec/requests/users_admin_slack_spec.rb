# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: the admin user surface manages slack_user_id — the field
# that drives a user's Slack notifications. Admin create persists it; admin
# update sets and clears it; the admin view returns it so the UI can show
# the current value; and every admin-made change lands in the audit trail
# with the admin as the actor. Self-service behavior is pinned separately
# in registrations_profile_update_spec.rb.
# ==========================================================================
RSpec.describe 'Admin user slack_user_id management' do
  # admin first — prevents first-user-admin promotion of the target
  let!(:admin_user) { create(:user, admin: true) }
  let!(:target_user) { create(:user, admin: false, slack_user_id: 'U0OLD') }
  let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

  before do
    Rails.application.reload_routes!
    sign_in admin_user
  end

  describe 'POST /users/admin_create' do
    it 'persists slack_user_id and returns it in the admin view' do
      post '/users/admin_create',
           params: { user: { name: 'Slacked User', email: 'slacked@example.com',
                             slack_user_id: 'U0NEW123' } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(User.find_by!(email: 'slacked@example.com').slack_user_id).to eq('U0NEW123')
      expect(response.parsed_body['user']['slack_user_id']).to eq('U0NEW123')
    end
  end

  describe 'PUT /users/:id' do
    it 'sets slack_user_id and returns it in the admin view' do
      put "/users/#{target_user.id}",
          params: { user: { name: target_user.name, email: target_user.email,
                            admin: false, slack_user_id: 'U0SET456' } }.to_json,
          headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(target_user.reload.slack_user_id).to eq('U0SET456')
      expect(response.parsed_body['user']['slack_user_id']).to eq('U0SET456')
    end

    it 'clears slack_user_id' do
      put "/users/#{target_user.id}",
          params: { user: { name: target_user.name, email: target_user.email,
                            admin: false, slack_user_id: '' } }.to_json,
          headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(target_user.reload.slack_user_id).to be_blank
    end
  end

  describe 'GET /users (admin index page)' do
    # The index HAML renders the :admin Blueprint view from a column-limited
    # select — a field added to the view but not the select 500s the whole
    # admin page (caught live during this card; invisible to the JSON specs).
    it 'renders with the slack-aware admin view' do
      get '/users'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('U0OLD')
    end
  end

  describe 'audit trail' do
    include_context 'with auditing'

    it 'records the admin-made slack_user_id change with the admin as actor' do
      put "/users/#{target_user.id}",
          params: { user: { name: target_user.name, email: target_user.email,
                            admin: false, slack_user_id: 'U0AUDIT9' } }.to_json,
          headers: json_headers

      expect(response).to have_http_status(:ok)
      audit = target_user.reload.audits.last
      expect(audit.audited_changes['slack_user_id']).to eq(%w[U0OLD U0AUDIT9])
      expect(audit.user_id).to eq(admin_user.id)
    end
  end
end
