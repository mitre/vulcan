# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
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
