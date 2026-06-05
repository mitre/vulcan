# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
  include_context 'components request base setup'

  # REQUIREMENT: Activity panel (B5) needs a dedicated histories endpoint
  # so the frontend can re-fetch after rule saves without full page reload.
  describe 'GET /components/:id/histories' do
    it 'requires authentication' do
      sign_out user
      get "/components/#{component.id}/histories",
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end

    it 'returns an array of formatted audit entries' do
      # Create a change to generate an audit
      rule = component.rules.first
      rule.update!(title: 'Updated for history test', audit_comment: 'Test history')

      get "/components/#{component.id}/histories",
          headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json).to be_an(Array)
      expect(json.length).to be > 0
      # Each entry should have the VulcanAudit.format structure
      entry = json.first
      expect(entry).to have_key('action')
      expect(entry).to have_key('audited_changes')
      expect(entry).to have_key('created_at')
    end

    it 'returns 404 for non-existent component' do
      get '/components/999999/histories',
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /components/:id/comments' do
    before do
      rule = component.rules.first
      create(:review, :comment, comment: 'check issue', user: user, rule: rule, section: 'check_content')
    end

    it 'returns paginated comments + DISA-native triage_status on the wire' do
      get "/components/#{component.id}/comments", params: { triage_status: 'all' },
                                                  headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body).to have_key('rows')
      expect(body).to have_key('pagination')
      expect(body['rows'].first['triage_status']).to eq('pending') # DISA-native, not 'Pending'
      expect(body['rows'].first['section']).to eq('check_content') # XCCDF key, not "Check"
    end

    it 'returns 404 for a non-existent component' do
      get '/components/99999999/comments', headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:not_found)
    end

    it 'filters by section' do
      get "/components/#{component.id}/comments",
          params: { triage_status: 'all', section: 'fixtext' },
          headers: { 'Accept' => application_json }
      expect(response.parsed_body['rows'].size).to eq(0)
    end

    it 'redirects HTML requests to the triage page' do
      get "/components/#{component.id}/comments"
      expect(response).to redirect_to("/components/#{component.id}/triage")
    end

    it 'includes status_counts hash with per-status totals' do
      get "/components/#{component.id}/comments", params: { triage_status: 'all' },
                                                  headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body).to have_key('status_counts')
      expect(body['status_counts']).to be_a(Hash)
      expect(body['status_counts']['pending']).to eq(1)
    end

    it 'sets Cache-Control: no-store so browsers/proxies cannot cache the queue' do
      get "/components/#{component.id}/comments", headers: { 'Accept' => application_json }
      expect(response.headers['Cache-Control'].to_s).to match(/no-store/i)
    end
  end
end
