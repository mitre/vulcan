# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Audits' do
  before do
    Rails.application.reload_routes!
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:json_headers) { { 'Accept' => 'application/json' } }

  # Create some audit records by modifying data
  def create_audit_records
    user = create(:user, name: 'Audit Target User')
    user.update!(name: 'Updated Name')
    project = create(:project, name: 'Audit Test Project')
    project.destroy
  end

  describe 'GET /admin/audits' do
    context 'when not authenticated' do
      it 'redirects to login' do
        get '/admin/audits'
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as regular user' do
      before { sign_in regular_user }

      it 'redirects with authorization error' do
        get '/admin/audits'
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when authenticated as admin' do
      before do
        sign_in admin_user
        create_audit_records
      end

      it 'responds to HTML request' do
        get '/admin/audits', headers: { 'Accept' => 'text/html' }
        expect(response.status).to be < 500
      end

      it 'returns audits list JSON with pagination' do
        get '/admin/audits', headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json['audits']).to be_an(Array)
        expect(json['audits'].length).to be >= 1

        # Check audit structure
        audit = json['audits'].first
        expect(audit).to have_key('id')
        expect(audit).to have_key('auditable_type')
        expect(audit).to have_key('auditable_id')
        expect(audit).to have_key('action')
        expect(audit).to have_key('version')
        expect(audit).to have_key('user_name')
        expect(audit).to have_key('created_at')
        expect(audit).to have_key('changes_summary')

        # Check pagination is included
        expect(json['pagination']).to be_a(Hash)
        expect(json['pagination']['page']).to eq(1)
        expect(json['pagination']['per_page']).to eq(50)
        expect(json['pagination']['total']).to be >= 1
        expect(json['pagination']['total_pages']).to be >= 1

        # Check filters are included
        expect(json['filters']).to be_a(Hash)
        expect(json['filters']).to have_key('auditable_types')
        expect(json['filters']).to have_key('actions')
      end

      it 'respects pagination parameters' do
        get '/admin/audits', params: { page: 1, per_page: 10 }, headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json['pagination']['per_page']).to eq(10)
        expect(json['pagination']['page']).to eq(1)
      end

      it 'clamps per_page to valid range' do
        get '/admin/audits', params: { per_page: 500 }, headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        # Should be clamped to 100 (max)
        expect(json['pagination']['per_page']).to eq(100)
      end

      it 'filters by auditable_type' do
        get '/admin/audits', params: { auditable_type: 'User' }, headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json['audits'].all? { |a| a['auditable_type'] == 'User' }).to be true
      end

      it 'filters by action_type' do
        get '/admin/audits', params: { action_type: 'create' }, headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json['audits'].all? { |a| a['action'] == 'create' }).to be true
      end

      it 'filters by date range' do
        # Create an old audit and a new one
        old_audit = Audited::Audit.first
        old_audit.update_column(:created_at, 1.year.ago) if old_audit

        today = Time.zone.today
        get '/admin/audits',
            params: { from_date: today.to_s, to_date: today.to_s },
            headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        # All returned audits should be from today
        json['audits'].each do |audit|
          audit_date = Date.parse(audit['created_at'])
          expect(audit_date).to be >= today.beginning_of_day
        end
      end
    end
  end

  describe 'GET /admin/audits/:id' do
    context 'when authenticated as admin' do
      before do
        sign_in admin_user
        create_audit_records
      end

      it 'returns audit detail JSON' do
        audit = Audited::Audit.first

        get "/admin/audits/#{audit.id}", headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json['audit']).to be_a(Hash)
        expect(json['audit']['id']).to eq(audit.id)
        expect(json['audit']['auditable_type']).to eq(audit.auditable_type)
        expect(json['audit']['action']).to eq(audit.action)
        expect(json['audit']).to have_key('audited_changes')
        expect(json['audit']).to have_key('auditable_exists')
      end

      it 'returns error for non-existent audit' do
        get '/admin/audits/999999', headers: json_headers
        expect(response.status).to be >= 400
      end
    end
  end

  describe 'GET /admin/audits/stats' do
    context 'when authenticated as admin' do
      before do
        sign_in admin_user
        create_audit_records
      end

      it 'returns audit statistics' do
        get '/admin/audits/stats', headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json).to have_key('total_audits')
        expect(json).to have_key('audits_today')
        expect(json).to have_key('audits_this_week')
        expect(json).to have_key('by_type')
        expect(json).to have_key('by_action')
        expect(json).to have_key('cached_at')

        expect(json['total_audits']).to be >= 1
        expect(json['by_type']).to be_a(Hash)
        expect(json['by_action']).to be_a(Hash)
      end

      it 'caches stats for performance' do
        # First request
        get '/admin/audits/stats', headers: json_headers
        first_cached_at = response.parsed_body['cached_at']

        # Second request should use cache
        get '/admin/audits/stats', headers: json_headers
        second_cached_at = response.parsed_body['cached_at']

        expect(first_cached_at).to eq(second_cached_at)
      end
    end
  end
end
