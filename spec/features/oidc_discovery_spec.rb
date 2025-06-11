# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

# This file uses mock-based testing - WebMock configuration is per-example
# Integration tests that need real HTTP requests are in spec/integration/

RSpec.describe 'OIDC Discovery Integration', type: :feature do
  let(:mock_discovery_response) do
    {
      'issuer' => 'https://example.okta.com',
      'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
      'token_endpoint' => 'https://example.okta.com/oauth2/v1/token',
      'userinfo_endpoint' => 'https://example.okta.com/oauth2/v1/userinfo',
      'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout',
      'response_types_supported' => ['code'],
      'subject_types_supported' => ['public'],
      'id_token_signing_alg_values_supported' => ['RS256']
    }
  end

  before do
    # Mock OIDC settings for tests
    allow(Settings.oidc).to receive(:enabled).and_return(true)
    allow(Settings.oidc).to receive(:discovery).and_return(true)

    oidc_args = double('oidc_args')
    allow(oidc_args).to receive(:issuer).and_return('https://example.okta.com')
    allow(Settings.oidc).to receive(:args).and_return(oidc_args)

    # Mock discovery endpoint with WebMock
    stub_request(:get, 'https://example.okta.com/.well-known/openid-configuration')
      .to_return(status: 200, body: mock_discovery_response.to_json)
  end

  context 'with discovery enabled' do
    it 'automatically configures OIDC endpoints' do
      # Simulate a controller that would use discovery
      controller = SessionsController.new
      allow(controller).to receive(:session).and_return({})

      # Test that discovery is used for logout endpoint
      logout_endpoint = controller.send(:fetch_oidc_logout_endpoint)
      expect(logout_endpoint).to eq('https://example.okta.com/oauth2/v1/logout')

      # Verify that the discovery endpoint was called
      expect(a_request(:get, 'https://example.okta.com/.well-known/openid-configuration')).to have_been_made.once
    end

    it 'caches discovery results in session' do
      controller = SessionsController.new
      session_cache = {}
      allow(controller).to receive(:session).and_return(session_cache)

      # First call should hit the discovery endpoint
      controller.send(:fetch_oidc_logout_endpoint)
      expect(a_request(:get, 'https://example.okta.com/.well-known/openid-configuration')).to have_been_made.once

      # Verify cache was populated
      expect(session_cache['oidc_discovery']).to be_present
      expect(session_cache['oidc_discovery']['end_session_endpoint']).to eq('https://example.okta.com/oauth2/v1/logout')

      # Second call should use cache, not hit endpoint again
      controller.send(:fetch_oidc_logout_endpoint)
      expect(a_request(:get, 'https://example.okta.com/.well-known/openid-configuration')).to have_been_made.once
    end
  end

  context 'with discovery disabled' do
    before do
      allow(Settings.oidc).to receive(:discovery).and_return(false)
    end

    it 'uses manual configuration' do
      controller = SessionsController.new
      allow(controller).to receive(:session).and_return({})

      # Should fall back to manual Okta-style URL without hitting discovery
      logout_endpoint = controller.send(:fetch_oidc_logout_endpoint)
      expect(logout_endpoint).to eq('https://example.okta.com/oauth2/v1/logout')

      # Verify discovery endpoint was not called
      expect(a_request(:get, 'https://example.okta.com/.well-known/openid-configuration')).not_to have_been_made
    end
  end

  context 'when discovery fails' do
    before do
      # Mock failed discovery response
      stub_request(:get, 'https://example.okta.com/.well-known/openid-configuration')
        .to_return(status: 404, body: 'Not Found')
    end

    it 'falls back to manual configuration gracefully' do
      controller = SessionsController.new
      allow(controller).to receive(:session).and_return({})

      # Should fall back to manual Okta-style URL
      logout_endpoint = controller.send(:fetch_oidc_logout_endpoint)
      expect(logout_endpoint).to eq('https://example.okta.com/oauth2/v1/logout')

      # Verify discovery was attempted but fallback was used
      expect(a_request(:get, 'https://example.okta.com/.well-known/openid-configuration')).to have_been_made.once
    end
  end
end
