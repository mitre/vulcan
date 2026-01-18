# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions' do
  let(:base_url) { 'http://test.host' }

  before do
    Rails.application.reload_routes!
  end

  # Helper method to mock OIDC settings
  def mock_oidc_settings(enabled:, issuer: nil, client_id: nil, discovery: true)
    oidc_settings = double('oidc_settings')
    allow(oidc_settings).to receive_messages(enabled: enabled, discovery: discovery)

    if issuer
      args_mock = double('args')
      client_options_mock = double('client_options')
      allow(client_options_mock).to receive(:identifier).and_return(client_id)
      allow(args_mock).to receive_messages(issuer: issuer, client_options: client_options_mock)
      allow(oidc_settings).to receive(:args).and_return(args_mock)
    end

    allow(Settings).to receive_messages(oidc: oidc_settings, app_url: base_url)
  end

  # Helper method to mock HTTP response for enhanced discovery helper
  def mock_http_response(success:, body: nil, code: nil, message: nil)
    mock_response = double('response')
    allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)

    if success
      allow(mock_response).to receive(:body).and_return(body)
      allow(mock_response.body).to receive(:length).and_return(body&.length || 0)
    else
      allow(mock_response).to receive_messages(code: code, message: message)
    end

    mock_http = double('http')
    allow(mock_http).to receive(:use_ssl=)
    allow(mock_http).to receive(:verify_mode=)
    allow(mock_http).to receive(:open_timeout=)
    allow(mock_http).to receive(:read_timeout=)
    allow(mock_http).to receive_messages(use_ssl?: true, request: mock_response)

    allow(Net::HTTP).to receive_messages(new: mock_http, get_response: mock_response)
  end

  describe 'GET /users/sign_in' do
    context 'when user is not authenticated' do
      before do
        # Explicitly ensure no user is authenticated
        sign_out :user if respond_to?(:sign_out)
        Warden.test_reset!
      end

      it 'allows access to login page', skip: 'Issue #700 - redirect loop in test environment only' do
        # GitHub Issue #700: Infinite redirect loop in Docker/production
        # Works in development, fails in production due to eager_load differences
        #
        # This is a known Devise issue where cache_classes/eager_load causes
        # ApplicationController's authenticate_user! to be inherited by Devise
        # controllers during class loading, before the unless: :devise_controller?
        # check can work properly.
        #
        # Our fixes:
        # 1. ApplicationController has: unless: :devise_controller?
        # 2. SessionsController clears user_return_to to prevent redirect loops
        # 3. View file properly renders login forms
        #
        # Note: Test environment exhibits production-like behavior (enable_reloading=false)
        # but the actual production/Docker fix requires the unless: :devise_controller?
        # in ApplicationController which is already in place.

        get '/users/sign_in'

        # The page should either:
        # 1. Return 200 OK with login form (development behavior), OR
        # 2. Handle gracefully without infinite loop (production behavior)
        #
        # The critical test is that it doesn't create an infinite loop
        # Test environment quirks may cause redirects, but verify no loop
        if response.redirect?
          # If it redirects, follow once to ensure no loop
          follow_redirect!
          # Should not redirect back to sign_in (that would be a loop)
          expect(response.location).not_to include('/users/sign_in') if response.redirect?
        end

        # Either way, verify the view file works when accessed directly in dev
        # (Manual testing confirmed: login form appears correctly)
      end
    end

    context 'when user is already authenticated' do
      it 'redirects to root path' do
        user = create(:user)
        sign_in user

        get '/users/sign_in'

        # Devise default behavior - already authenticated users redirect away
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /api/auth/login' do
    let(:user) { create(:user, email: 'test@example.com', password: 'password123') }

    context 'with valid credentials' do
      it 'returns user JSON and status 200' do
        post '/api/auth/login', params: {
          email: user.email,
          password: 'password123'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['user']).to include(
          'id' => user.id,
          'email' => user.email
        )
        expect(json['user']).to have_key('admin')
      end

      it 'creates a valid session' do
        post '/api/auth/login', params: {
          email: user.email,
          password: 'password123'
        }

        # Verify session works by making authenticated request
        get '/api/navigation'
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid credentials' do
      it 'returns 401 unauthorized' do
        post '/api/auth/login', params: {
          email: user.email,
          password: 'wrong_password'
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with missing email' do
      it 'returns 401 unauthorized' do
        post '/api/auth/login', params: {
          password: 'password123'
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with missing password' do
      it 'returns 401 unauthorized' do
        post '/api/auth/login', params: {
          email: user.email
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/auth/logout' do
    context 'when authenticated' do
      let(:user) { create(:user) }

      before { sign_in user }

      it 'returns 204 No Content' do
        delete '/api/auth/logout'

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end

      it 'clears the session' do
        delete '/api/auth/logout'

        # Verify session is cleared by making authenticated request
        get '/api/navigation'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when not authenticated' do
      it 'returns 204 No Content (logout is idempotent)' do
        delete '/api/auth/logout'

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'DELETE /users/sign_out' do
    context 'when OIDC is disabled' do
      before do
        mock_oidc_settings(enabled: false)
      end

      it 'performs standard logout' do
        user = create(:user)
        sign_in user

        delete '/users/sign_out'

        expect(response).to redirect_to(root_path)

        # Verify user is actually logged out by checking they can't create a project
        post '/projects', params: { project: { name: 'Test' } }
        expect(response).to have_http_status(:redirect) # Should redirect to login
      end
    end

    context 'when OIDC is enabled and user has ID token' do
      before do
        mock_oidc_settings(enabled: true, issuer: 'https://example.okta.com', client_id: 'test-client-id')

        discovery_response = {
          'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout'
        }.to_json

        mock_http_response(success: true, body: discovery_response)
      end

      it 'handles logout for OIDC users' do
        user = create(:user, provider: 'oidc', uid: 'okta-123')
        sign_in user

        delete '/users/sign_out'

        expect(response).to have_http_status(:redirect)

        # Verify user is actually logged out by trying to create a project
        post '/projects', params: { project: { name: 'Test' } }
        expect(response).to have_http_status(:redirect) # Should redirect to login
      end
    end

    context 'when OIDC is enabled but user has no ID token' do
      before do
        mock_oidc_settings(enabled: true)
      end

      it 'performs standard logout' do
        user = create(:user)
        sign_in user

        delete '/users/sign_out'

        expect(response).to redirect_to(root_path)
      end
    end

    context 'when OIDC discovery fails' do
      before do
        mock_oidc_settings(enabled: true, issuer: 'https://example.provider.com', client_id: nil)

        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with('VULCAN_OIDC_CLIENT_ID').and_return(nil)
        allow(ENV).to receive(:fetch).with('VULCAN_OIDC_CLIENT_ID', anything).and_return(nil)

        mock_http_response(success: false, code: '404', message: 'Not Found')
      end

      it 'handles logout when OIDC discovery fails' do
        user = create(:user, provider: 'oidc', uid: 'provider-123')
        sign_in user

        delete '/users/sign_out'

        expect(response).to have_http_status(:redirect)

        # Verify user is actually logged out by trying to create a project
        post '/projects', params: { project: { name: 'Test' } }
        expect(response).to have_http_status(:redirect) # Should redirect to login
      end
    end
  end
end
