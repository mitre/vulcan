# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe '#destroy' do
    context 'when OIDC is disabled' do
      before do
        allow(Settings.oidc).to receive(:enabled).and_return(false)
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
        # Create a mock for the entire Settings.oidc structure
        oidc_settings = double('oidc_settings')
        allow(oidc_settings).to receive(:enabled).and_return(true)
        
        # Create a mock for args with issuer
        args_mock = double('args')
        allow(args_mock).to receive(:issuer).and_return('https://example.okta.com')
        
        # Create a mock for client_options with identifier
        client_options_mock = double('client_options')
        allow(client_options_mock).to receive(:identifier).and_return('test-client-id')
        allow(args_mock).to receive(:client_options).and_return(client_options_mock)
        
        allow(oidc_settings).to receive(:args).and_return(args_mock)
        
        allow(Settings).to receive(:oidc).and_return(oidc_settings)
        allow(Settings).to receive(:app_url).and_return('http://localhost:3000')
        
        # Mock the OIDC discovery response
        discovery_response = {
          'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout'
        }.to_json
        
        mock_response = double('response')
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_response).to receive(:body).and_return(discovery_response)
        
        allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
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
        expect(params['post_logout_redirect_uri']).to eq(['http://localhost:3000'])
        expect(params['client_id']).to eq(['test-client-id'])
        expect(controller.current_user).to be_nil
        expect(session[:id_token]).to be_nil
      end
    end

    context 'when OIDC is enabled but user has no ID token' do
      before do
        allow(Settings.oidc).to receive(:enabled).and_return(true)
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
        # Create a mock for the entire Settings.oidc structure
        oidc_settings = double('oidc_settings')
        allow(oidc_settings).to receive(:enabled).and_return(true)
        
        # Create a mock for args with issuer
        args_mock = double('args')
        allow(args_mock).to receive(:issuer).and_return('https://example.provider.com')
        
        # Create a mock for client_options with no identifier
        client_options_mock = double('client_options')
        allow(client_options_mock).to receive(:identifier).and_return(nil)
        allow(args_mock).to receive(:client_options).and_return(client_options_mock)
        
        allow(oidc_settings).to receive(:args).and_return(args_mock)
        
        allow(Settings).to receive(:oidc).and_return(oidc_settings)
        allow(Settings).to receive(:app_url).and_return('http://localhost:3000')
        
        # Mock ENV to ensure no client_id is picked up
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('VULCAN_OIDC_CLIENT_ID').and_return(nil)
        
        # Mock failed discovery response
        mock_response = double('response')
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(mock_response).to receive(:code).and_return('404')
        allow(mock_response).to receive(:message).and_return('Not Found')
        
        allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
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
        params = CGI.parse(uri.query)
        
        expect(uri.to_s).to start_with('https://example.provider.com/oauth2/v1/logout')
        expect(params['id_token_hint']).to eq(['fake-id-token'])
        expect(params['post_logout_redirect_uri']).to eq(['http://localhost:3000'])
        # No client_id when not configured
        expect(params['client_id']).to eq([])
      end
    end
  end
end