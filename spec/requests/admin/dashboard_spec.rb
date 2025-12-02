# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Dashboard' do
  before do
    Rails.application.reload_routes!
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:json_headers) { { 'Accept' => 'application/json' } }

  describe 'GET /admin (index)' do
    context 'when not authenticated' do
      it 'redirects to login' do
        get '/admin'
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as regular user' do
      before { sign_in regular_user }

      it 'redirects with authorization error' do
        get '/admin'
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin_user }

      it 'renders HTML page or redirects to SPA' do
        get '/admin'
        # Admin pages may redirect to SPA root or render directly
        expect(response).to have_http_status(:ok).or have_http_status(:found)
      end

      it 'returns stats JSON for JSON request' do
        get '/admin', headers: json_headers
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json = response.parsed_body
        expect(json).to have_key('users')
        expect(json).to have_key('projects')
        expect(json).to have_key('components')
        expect(json).to have_key('stigs')
        expect(json).to have_key('srgs')
        expect(json).to have_key('recent_activity')
      end
    end
  end

  describe 'GET /admin/stats' do
    context 'when not authenticated' do
      it 'redirects to login' do
        get '/admin/stats'
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin_user }

      it 'returns stats JSON' do
        get '/admin/stats'
        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['users']).to include('total', 'local', 'external', 'admins', 'locked')
        expect(json['projects']).to include('total', 'recent')
        expect(json['components']).to include('total', 'released')
        expect(json['stigs']).to include('total')
        expect(json['srgs']).to include('total')
      end

      it 'returns correct user counts' do
        # Create additional users
        create(:user, admin: false)
        create(:user, admin: false, provider: 'oidc', uid: 'ext123')
        locked_user = create(:user, admin: false)
        locked_user.lock_access!

        get '/admin/stats'
        json = response.parsed_body

        expect(json['users']['total']).to be >= 4
        expect(json['users']['admins']).to be >= 1
        expect(json['users']['locked']).to be >= 1
        expect(json['users']['external']).to be >= 1
      end

      it 'returns recent activity' do
        # Create an auditable action
        project = create(:project)

        get '/admin/stats'
        json = response.parsed_body

        expect(json['recent_activity']).to be_an(Array)
        expect(json['recent_activity'].length).to be <= 20
      end
    end
  end
end
