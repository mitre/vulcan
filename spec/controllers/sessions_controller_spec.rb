# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  BASE_URL = 'http://localhost:3000' # rubocop:disable Lint/ConstantDefinitionInBlock
  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  # Helper method to mock OIDC settings
  def mock_oidc_settings(enabled:, issuer: nil, client_id: nil, discovery: true)
    oidc_settings = double('oidc_settings')
    allow(oidc_settings).to receive(:enabled).and_return(enabled)
    allow(oidc_settings).to receive(:discovery).and_return(discovery)

    if issuer
      args_mock = double('args')
      allow(args_mock).to receive(:issuer).and_return(issuer)

      client_options_mock = double('client_options')
      allow(client_options_mock).to receive(:identifier).and_return(client_id)
      allow(args_mock).to receive(:client_options).and_return(client_options_mock)

      allow(oidc_settings).to receive(:args).and_return(args_mock)
    end

    allow(Settings).to receive(:oidc).and_return(oidc_settings)
    allow(Settings).to receive(:app_url).and_return(BASE_URL)
  end

  # Helper method to mock HTTP response for enhanced discovery helper
  def mock_http_response(success:, body: nil, code: nil, message: nil)
    mock_response = double('response')
    allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)

    if success
      allow(mock_response).to receive(:body).and_return(body)
      # Mock body length for security check
      allow(mock_response.body).to receive(:length).and_return(body&.length || 0)
    else
      allow(mock_response).to receive(:code).and_return(code)
      allow(mock_response).to receive(:message).and_return(message)
    end

    # Mock the Net::HTTP instance and its request method
    mock_http = double('http')
    allow(Net::HTTP).to receive(:new).and_return(mock_http)
    allow(mock_http).to receive(:use_ssl=)
    allow(mock_http).to receive(:verify_mode=)
    allow(mock_http).to receive(:open_timeout=)
    allow(mock_http).to receive(:read_timeout=)
    allow(mock_http).to receive(:use_ssl?).and_return(true)
    allow(mock_http).to receive(:request).and_return(mock_response)

    # Also support the old get_response for backward compatibility
    allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
  end

  describe '#destroy' do
    context 'when OIDC is disabled' do
      before do
        mock_oidc_settings(enabled: false)
      end

      it 'performs standard logout' do
        user = create(:user)
        sign_in user

        delete :destroy

        expect(response).to redirect_to(root_path)
        expect(controller.current_user).to be_nil
      end
    end

    context 'when OIDC is enabled and user has ID token' do
      before do
        mock_oidc_settings(enabled: true, issuer: 'https://example.okta.com', client_id: 'test-client-id')

        # Mock the OIDC discovery response
        discovery_response = {
          'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout'
        }.to_json

        mock_http_response(success: true, body: discovery_response)
      end

      it 'redirects to OIDC logout URL with ID token' do
        user = create(:user, provider: 'oidc', uid: 'okta-123')
        sign_in user

        # Simulate storing ID token in session
        session[:id_token] = 'fake-id-token-12345'

        delete :destroy

        # Check that we redirect to the correct logout URL with all parameters
        expect(response).to have_http_status(:redirect)
        redirect_url = response.location
        uri = URI.parse(redirect_url)
        params = CGI.parse(uri.query)

        expect(uri.to_s).to start_with('https://example.okta.com/oauth2/v1/logout')
        expect(params['id_token_hint']).to eq(['fake-id-token-12345'])
        expect(params['post_logout_redirect_uri']).to eq([BASE_URL])
        expect(params['client_id']).to eq(['test-client-id'])
        expect(controller.current_user).to be_nil
        expect(session[:id_token]).to be_nil
      end
    end

    context 'when OIDC is enabled but user has no ID token' do
      before do
        mock_oidc_settings(enabled: true)
      end

      it 'performs standard logout' do
        user = create(:user)
        sign_in user

        delete :destroy

        expect(response).to redirect_to(root_path)
        expect(controller.current_user).to be_nil
      end
    end

    context 'when OIDC discovery fails' do
      before do
        mock_oidc_settings(enabled: true, issuer: 'https://example.provider.com', client_id: nil)

        # Mock ENV to ensure no client_id is picked up
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('VULCAN_OIDC_CLIENT_ID').and_return(nil)

        # Mock failed discovery response
        mock_http_response(success: false, code: '404', message: 'Not Found')
      end

      it 'falls back to OKTA-style logout URL' do
        user = create(:user, provider: 'oidc', uid: 'provider-123')
        sign_in user
        session[:id_token] = 'fake-id-token'

        delete :destroy

        # Check fallback to OKTA-style endpoint
        expect(response).to have_http_status(:redirect)
        redirect_url = response.location
        uri = URI.parse(redirect_url)
        params = uri.query ? CGI.parse(uri.query) : {}

        expect(uri.to_s).to start_with('https://example.provider.com/oauth2/v1/logout')
        expect(params['id_token_hint']).to eq(['fake-id-token'])
        expect(params['post_logout_redirect_uri']).to eq(['http://localhost:3000'])
        # No client_id when not configured
        expect(params['client_id']).to eq([])
      end
    end
  end

  describe '#fetch_oidc_logout_endpoint' do
    context 'when discovery is enabled' do
      before { mock_oidc_settings(enabled: true, issuer: 'https://example.okta.com', discovery: true) }

      it 'uses discovered endpoint when available' do
        controller.send(:define_singleton_method, :session) { {} }

        discovery_response = {
          'issuer' => 'https://example.okta.com',
          'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout',
          'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
          'response_types_supported' => ['code'],
          'subject_types_supported' => ['public'],
          'id_token_signing_alg_values_supported' => ['RS256']
        }.to_json

        mock_http_response(success: true, body: discovery_response)

        endpoint = controller.send(:fetch_oidc_logout_endpoint)
        expect(endpoint).to eq('https://example.okta.com/oauth2/v1/logout')
      end

      it 'falls back to manual config when discovery fails' do
        controller.send(:define_singleton_method, :session) { {} }

        mock_http_response(success: false, code: '404', message: 'Not Found')

        endpoint = controller.send(:fetch_oidc_logout_endpoint)
        expect(endpoint).to eq('https://example.okta.com/oauth2/v1/logout')
      end
    end

    context 'when discovery is disabled' do
      before { mock_oidc_settings(enabled: true, issuer: 'https://example.okta.com', discovery: false) }

      it 'uses manual configuration' do
        controller.send(:define_singleton_method, :session) { {} }

        endpoint = controller.send(:fetch_oidc_logout_endpoint)
        expect(endpoint).to eq('https://example.okta.com/oauth2/v1/logout')
      end
    end
  end

  describe 'Phase 1 Enhancements: Cache Management & Edge Cases' do
    before { mock_oidc_settings(enabled: true, issuer: 'https://example.okta.com', discovery: true) }

    describe 'concurrent request handling' do
      it 'prevents duplicate discovery requests' do
        session_cache = { 'oidc_discovery_requesting' => true }
        controller.send(:define_singleton_method, :session) { session_cache }

        # Mock a successful discovery response (this should not be called)
        discovery_response = {
          'issuer' => 'https://example.okta.com',
          'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
          'response_types_supported' => ['code'],
          'subject_types_supported' => ['public'],
          'id_token_signing_alg_values_supported' => ['RS256'],
          'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout'
        }.to_json

        mock_http_response(success: true, body: discovery_response)

        # This should return nil (triggering fallback) instead of making another request
        result = controller.send(:fetch_oidc_discovery_document, 'https://example.okta.com')
        expect(result).to be_nil

        # Verify the request flag is still set (not cleared by our request)
        expect(session_cache['oidc_discovery_requesting']).to be_truthy
      end
    end

    describe 'cache invalidation on issuer change' do
      it 'invalidates cache when issuer URL changes' do
        session_cache = {}
        controller.send(:define_singleton_method, :session) { session_cache }

        # Cache discovery for first issuer
        old_discovery = {
          'issuer' => 'https://old.okta.com',
          'authorization_endpoint' => 'https://old.okta.com/oauth2/v1/authorize',
          'expires_at' => 1.hour.from_now,
          'vulcan_cache_version' => '1.1'
        }
        session_cache['oidc_discovery'] = old_discovery

        # Request discovery for new issuer should invalidate cache
        new_discovery_response = {
          'issuer' => 'https://example.okta.com',
          'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
          'response_types_supported' => ['code'],
          'subject_types_supported' => ['public'],
          'id_token_signing_alg_values_supported' => ['RS256']
        }.to_json

        mock_http_response(success: true, body: new_discovery_response)

        result = controller.send(:fetch_oidc_discovery_document, 'https://example.okta.com')

        expect(result).to be_present
        expect(result['issuer']).to eq('https://example.okta.com')
        # Verify old cache was invalidated and new cache was set
        expect(session_cache['oidc_discovery']['issuer']).to eq('https://example.okta.com')
      end
    end

    describe 'partial discovery document handling' do
      it 'handles discovery documents missing optional fields' do
        controller.send(:define_singleton_method, :session) { {} }

        # Minimal valid discovery document (missing optional fields)
        minimal_discovery = {
          'issuer' => 'https://example.okta.com',
          'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
          'response_types_supported' => ['code'],
          'subject_types_supported' => ['public'],
          'id_token_signing_alg_values_supported' => ['RS256']
          # Missing: token_endpoint, userinfo_endpoint, jwks_uri, end_session_endpoint
        }.to_json

        mock_http_response(success: true, body: minimal_discovery)

        # Should succeed despite missing optional fields
        result = controller.send(:fetch_oidc_discovery_document, 'https://example.okta.com')

        expect(result).to be_present
        expect(result['issuer']).to eq('https://example.okta.com')
        expect(result['authorization_endpoint']).to be_present
        # Optional fields should be missing but not cause failure
        expect(result['token_endpoint']).to be_nil
        expect(result['end_session_endpoint']).to be_nil
      end

      it 'handles discovery documents with unknown future fields' do
        controller.send(:define_singleton_method, :session) { {} }

        # Discovery document with future/unknown fields
        future_discovery = {
          'issuer' => 'https://example.okta.com',
          'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
          'response_types_supported' => ['code'],
          'subject_types_supported' => ['public'],
          'id_token_signing_alg_values_supported' => ['RS256'],
          'token_endpoint' => 'https://example.okta.com/oauth2/v1/token',
          # Unknown future fields
          'future_oidc_extension' => 'some_value',
          'new_security_feature' => %w[option1 option2]
        }.to_json

        mock_http_response(success: true, body: future_discovery)

        # Should succeed and preserve unknown fields
        result = controller.send(:fetch_oidc_discovery_document, 'https://example.okta.com')

        expect(result).to be_present
        expect(result['issuer']).to eq('https://example.okta.com')
        # Unknown fields should be preserved
        expect(result['future_oidc_extension']).to eq('some_value')
        expect(result['new_security_feature']).to eq(%w[option1 option2])
      end
    end

    describe 'cache version compatibility' do
      it 'invalidates cache with old version numbers' do
        session_cache = {}
        controller.send(:define_singleton_method, :session) { session_cache }

        # Cache with old version
        old_version_cache = {
          'issuer' => 'https://example.okta.com',
          'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
          'expires_at' => 1.hour.from_now,
          'vulcan_cache_version' => '1.0' # Old version
        }
        session_cache['oidc_discovery'] = old_version_cache

        new_discovery_response = {
          'issuer' => 'https://example.okta.com',
          'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
          'response_types_supported' => ['code'],
          'subject_types_supported' => ['public'],
          'id_token_signing_alg_values_supported' => ['RS256']
        }.to_json

        mock_http_response(success: true, body: new_discovery_response)

        result = controller.send(:fetch_oidc_discovery_document, 'https://example.okta.com')

        expect(result).to be_present
        # Should have refreshed cache with new version
        expect(session_cache['oidc_discovery']['vulcan_cache_version']).to eq('1.1')
      end
    end
  end
end
