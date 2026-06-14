# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions' do
  let(:base_url) { 'http://test.host' }

  before do
    Rails.application.reload_routes!
  end

  # Helper method to mock OIDC settings
  def mock_oidc_settings(enabled:, issuer: nil, client_id: nil, discovery: true, provider_name: 'oidc')
    oidc_settings = double('oidc_settings')
    allow(oidc_settings).to receive_messages(enabled: enabled, discovery: discovery)

    if issuer
      args_mock = double('args')
      client_options_mock = double('client_options')
      allow(client_options_mock).to receive(:identifier).and_return(client_id)
      allow(args_mock).to receive_messages(issuer: issuer, client_options: client_options_mock)
      allow(oidc_settings).to receive_messages(
        args: args_mock,
        providers: [{ 'name' => provider_name, 'issuer' => issuer, 'client_id' => client_id }]
      )
    else
      allow(oidc_settings).to receive(:providers).and_return([])
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

  # RP-initiated logout landing: the OIDC provider returns the browser here
  # after ending its session. The landing produces the AC-12(02) logoff
  # message locally (a flash set BEFORE the provider hop would die during
  # the external redirect) and forwards to the sign-in page in ONE redirect
  # so the flash survives to render.
  describe 'GET /users/signed_out' do
    it 'sets the signed-out flash and redirects to the sign-in page (unauthenticated)' do
      get '/users/signed_out'

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to eq(I18n.t('devise.sessions.signed_out'))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Signed out successfully.')
    end

    it 'is idempotent and safe while still signed in (no session state assumed)' do
      user = create(:user)
      sign_in user

      get '/users/signed_out'

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to eq(I18n.t('devise.sessions.signed_out'))
    end
  end

  # Real OIDC session sign-out: drives the actual omniauth flow so
  # session[:id_token] is populated exactly as production does, then
  # exercises SessionsController#destroy's provider-logout branch.
  describe 'DELETE /users/sign_out with an OIDC session' do
    let(:user) { create(:user, provider: 'oidc', uid: 'okta-123') }

    def sign_in_via_oidc(user)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(
        provider: 'oidc',
        uid: user.uid,
        info: { name: user.name, email: user.email },
        credentials: { id_token: 'fake-id-token' },
        extra: { raw_info: {} }
      )
      post '/users/auth/oidc'
      follow_redirect! # callback — stores session[:id_token]
    end

    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:oidc] = nil
    end

    it 'redirects to the discovered end_session_endpoint when the provider publishes one' do
      mock_oidc_settings(enabled: true, issuer: 'https://example.okta.com', client_id: 'test-client-id')
      mock_http_response(
        success: true,
        body: { 'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout' }.to_json
      )
      sign_in_via_oidc(user)

      delete '/users/sign_out'

      expect(response.location).to start_with('https://example.okta.com/oauth2/v1/logout?')
      expect(response.location).to include('id_token_hint=fake-id-token')
      expect(response.location).to include(CGI.escape("#{base_url}/users/signed_out"))
    end

    it 'falls back to the Okta-shaped logout URL for an Okta issuer when discovery fails' do
      mock_oidc_settings(enabled: true, issuer: 'https://example.okta.com', client_id: 'test-client-id')
      mock_http_response(success: false, code: '404', message: 'Not Found')
      sign_in_via_oidc(user)

      delete '/users/sign_out'

      expect(response.location).to start_with('https://example.okta.com/oauth2/v1/logout?')
    end

    # RP-initiated logout is OPTIONAL in OIDC. A provider that does not
    # publish end_session_endpoint gets NO guessed URL — guessing produced
    # a 404 at the provider (e.g. https://gitlab.com/oauth2/v1/logout).
    # Local sign-out + the AC-12(02) message still happen.
    it 'completes locally with the signed-out flash when a non-Okta issuer has no endpoint' do
      mock_oidc_settings(enabled: true, issuer: 'https://gitlab.example.com', client_id: 'test-client-id')
      mock_http_response(success: false, code: '404', message: 'Not Found')
      sign_in_via_oidc(user)

      delete '/users/sign_out'

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to eq(I18n.t('devise.sessions.signed_out'))

      # Session really ended
      post '/projects', params: { project: { name: 'Test' } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'OIDC logout URL shape' do
    let(:user) { create(:user, provider: 'oidc', uid: 'okta-url-test') }

    def sign_in_via_oidc(user)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(
        provider: 'oidc', uid: user.uid,
        info: { name: user.name, email: user.email },
        credentials: { id_token: 'fake-id-token' },
        extra: { raw_info: {} }
      )
      post '/users/auth/oidc'
      follow_redirect!
    end

    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:oidc] = nil
    end

    it 'includes post_logout_redirect_uri pointing at /users/signed_out' do
      mock_oidc_settings(enabled: true, issuer: 'https://example.okta.com', client_id: 'test-client-id')
      mock_http_response(
        success: true,
        body: { 'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout' }.to_json
      )
      sign_in_via_oidc(user)

      delete '/users/sign_out'

      expect(response.location).to start_with('https://example.okta.com/oauth2/v1/logout?')
      expect(response.location).to include(CGI.escape('/users/signed_out'))
      expect(response.location).to include('id_token_hint=fake-id-token')
      expect(response.location).to include('client_id=test-client-id')
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

        expect(response).to redirect_to(new_user_session_path)

        # Verify user is actually logged out by checking they can't create a project
        post '/projects', params: { project: { name: 'Test' } }
        expect(response).to have_http_status(:redirect) # Should redirect to login
      end

      # The sign-in page must be ONE redirect away so the signed-out flash
      # survives to render. Devise's default after_sign_out path (root)
      # triggers a second auth redirect that consumes the flash before the
      # sign-in page renders — the Toaster never shows the confirmation.
      it 'redirects straight to the sign-in page with the signed-out flash intact' do
        user = create(:user)
        sign_in user

        delete '/users/sign_out'

        expect(response).to redirect_to(new_user_session_path)
        follow_redirect!
        expect(response).to have_http_status(:ok)
        expect(flash[:notice]).to eq('Signed out successfully.')
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

        expect(response).to redirect_to(new_user_session_path)
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
