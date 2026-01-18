# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Settings' do
  before do
    Rails.application.reload_routes!
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:json_headers) { { 'Accept' => 'application/json' } }

  describe 'GET /admin/settings' do
    context 'when not authenticated' do
      it 'redirects to login' do
        get '/admin/settings'
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as regular user' do
      before { sign_in regular_user }

      it 'redirects with authorization error' do
        get '/admin/settings'
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin_user }

      it 'renders HTML page or redirects to SPA' do
        get '/admin/settings'
        # Admin pages may redirect to SPA root or render directly
        expect(response).to have_http_status(:ok).or have_http_status(:found)
      end

      it 'returns settings JSON' do
        get '/admin/settings', headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json = response.parsed_body
        expect(json).to have_key('authentication')
        expect(json).to have_key('ldap')
        expect(json).to have_key('oidc')
        expect(json).to have_key('smtp')
        expect(json).to have_key('slack')
        expect(json).to have_key('project')
        expect(json).to have_key('app')
      end

      it 'returns authentication settings' do
        get '/admin/settings', headers: json_headers
        json = response.parsed_body

        auth = json['authentication']
        expect(auth).to have_key('local_login')
        expect(auth).to have_key('user_registration')
        expect(auth).to have_key('lockable')

        expect(auth['local_login']).to have_key('enabled')
        expect(auth['local_login']).to have_key('email_confirmation')
        expect(auth['local_login']).to have_key('session_timeout_minutes')

        expect(auth['lockable']).to have_key('enabled')
        expect(auth['lockable']).to have_key('max_attempts')
        expect(auth['lockable']).to have_key('unlock_in_minutes')
      end

      it 'returns ldap settings' do
        get '/admin/settings', headers: json_headers
        json = response.parsed_body

        expect(json['ldap']).to have_key('enabled')
        expect(json['ldap']).to have_key('title')
      end

      it 'returns oidc settings' do
        get '/admin/settings', headers: json_headers
        json = response.parsed_body

        expect(json['oidc']).to have_key('enabled')
        expect(json['oidc']).to have_key('title')
        expect(json['oidc']).to have_key('issuer')
      end

      it 'returns smtp settings' do
        get '/admin/settings', headers: json_headers
        json = response.parsed_body

        expect(json['smtp']).to have_key('enabled')
        expect(json['smtp']).to have_key('address')
        expect(json['smtp']).to have_key('port')
      end

      it 'returns slack settings' do
        get '/admin/settings', headers: json_headers
        json = response.parsed_body

        expect(json['slack']).to have_key('enabled')
      end

      it 'returns project settings' do
        get '/admin/settings', headers: json_headers
        json = response.parsed_body

        expect(json['project']).to have_key('create_permission_enabled')
      end

      it 'returns app settings' do
        get '/admin/settings', headers: json_headers
        json = response.parsed_body

        expect(json['app']).to have_key('url')
        expect(json['app']).to have_key('contact_email')
      end

      it 'does not expose sensitive secrets' do
        get '/admin/settings', headers: json_headers
        json = response.parsed_body

        json_string = json.to_json.downcase

        # Ensure no secrets are exposed
        expect(json_string).not_to include('password')
        expect(json_string).not_to include('secret')
        expect(json_string).not_to include('token')
        expect(json_string).not_to include('key')
      end
    end
  end
end
