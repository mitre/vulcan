# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Okta OIDC Discovery Integration', type: :system do
  # Allow real HTTP requests for integration testing
  before(:all) do
    WebMock.allow_net_connect! if defined?(WebMock)
  end

  after(:all) do
    WebMock.disable_net_connect!(allow_localhost: true) if defined?(WebMock)
  end
  # These tests use real Okta discovery endpoints to validate our implementation
  # against actual provider responses without requiring authentication

  before do
    # Skip if OIDC is not enabled or no issuer configured
    skip 'OIDC not configured - set VULCAN_ENABLE_OIDC=true and VULCAN_OIDC_ISSUER_URL to run these tests' unless oidc_enabled? && okta_test_issuer.present?
  end

  describe 'Real Okta Discovery Endpoint Testing' do
    let(:okta_test_issuer) { ENV['VULCAN_OIDC_ISSUER_URL'] || ENV.fetch('OKTA_TEST_ISSUER', nil) }
    let(:discovery_url) { "#{okta_test_issuer}/.well-known/openid-configuration" }

    context 'with live Okta discovery endpoint' do
      it 'successfully fetches and parses Okta discovery document' do
        # Mock OIDC settings for test
        mock_oidc_settings(enabled: true, issuer: okta_test_issuer, discovery: true)

        # Create a test controller instance
        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        # Test real discovery
        discovery_doc = controller.send(:fetch_oidc_discovery_document, okta_test_issuer)

        # Validate discovery succeeded
        expect(discovery_doc).to be_present
        expect(discovery_doc).to be_a(Hash)

        # Validate OIDC Core required fields are present
        expect(discovery_doc['issuer']).to eq(okta_test_issuer)
        expect(discovery_doc['authorization_endpoint']).to be_present
        expect(discovery_doc['response_types_supported']).to be_present
        expect(discovery_doc['subject_types_supported']).to be_present
        expect(discovery_doc['id_token_signing_alg_values_supported']).to be_present

        # Validate Okta-specific endpoints
        expect(discovery_doc['token_endpoint']).to be_present
        expect(discovery_doc['userinfo_endpoint']).to be_present
        expect(discovery_doc['jwks_uri']).to be_present

        # Okta should provide end_session_endpoint
        expect(discovery_doc['end_session_endpoint']).to be_present

        # Log discovered capabilities for debugging
        Rails.logger.info 'Okta Discovery Test Results:'
        Rails.logger.info "  Issuer: #{discovery_doc['issuer']}"
        Rails.logger.info "  Authorization: #{discovery_doc['authorization_endpoint'].present? ? '✓' : '✗'}"
        Rails.logger.info "  Token: #{discovery_doc['token_endpoint'].present? ? '✓' : '✗'}"
        Rails.logger.info "  Userinfo: #{discovery_doc['userinfo_endpoint'].present? ? '✓' : '✗'}"
        Rails.logger.info "  JWKS: #{discovery_doc['jwks_uri'].present? ? '✓' : '✗'}"
        Rails.logger.info "  End Session: #{discovery_doc['end_session_endpoint'].present? ? '✓' : '✗'}"
        Rails.logger.info "  Response Types: #{discovery_doc['response_types_supported']&.join(', ')}"
        Rails.logger.info "  Signing Algorithms: #{discovery_doc['id_token_signing_alg_values_supported']&.join(', ')}"
      end

      it 'validates Okta endpoint URLs use HTTPS' do
        mock_oidc_settings(enabled: true, issuer: okta_test_issuer, discovery: true)

        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        discovery_doc = controller.send(:fetch_oidc_discovery_document, okta_test_issuer)

        # All Okta endpoints should use HTTPS
        endpoint_fields = %w[
          issuer authorization_endpoint token_endpoint userinfo_endpoint
          jwks_uri end_session_endpoint revocation_endpoint introspection_endpoint
        ]

        endpoint_fields.each do |field|
          endpoint_url = discovery_doc[field]
          next if endpoint_url.blank?

          expect(endpoint_url).to start_with('https://'),
                                  "Okta #{field} should use HTTPS: #{endpoint_url}"
        end
      end

      it 'validates Okta supports required OIDC flows' do
        mock_oidc_settings(enabled: true, issuer: okta_test_issuer, discovery: true)

        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        discovery_doc = controller.send(:fetch_oidc_discovery_document, okta_test_issuer)

        # Okta should support authorization code flow
        response_types = discovery_doc['response_types_supported']
        expect(response_types).to include('code'),
                                  "Okta should support 'code' response type for authorization code flow"

        # Okta should support RS256 signing
        signing_algs = discovery_doc['id_token_signing_alg_values_supported']
        expect(signing_algs).to include('RS256'),
                                'Okta should support RS256 signing algorithm'

        # Okta should support 'public' subject type
        subject_types = discovery_doc['subject_types_supported']
        expect(subject_types).to include('public'),
                                 "Okta should support 'public' subject type"
      end

      it 'tests Okta logout endpoint discovery' do
        mock_oidc_settings(enabled: true, issuer: okta_test_issuer, discovery: true)

        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        # Test logout endpoint discovery specifically
        logout_endpoint = controller.send(:fetch_oidc_endpoint, 'end_session_endpoint')

        expect(logout_endpoint).to be_present
        expect(logout_endpoint).to start_with('https://')
        expect(logout_endpoint).to include('logout')

        Rails.logger.info "Okta Logout Endpoint: #{logout_endpoint}"
      end

      it 'validates discovery document caching works with Okta' do
        mock_oidc_settings(enabled: true, issuer: okta_test_issuer, discovery: true)

        controller = SessionsController.new
        # Clear Rails.cache to ensure fresh start
        Rails.cache.clear

        # First request should fetch from Okta
        start_time = Time.current
        discovery_doc1 = controller.send(:fetch_oidc_discovery_document, okta_test_issuer)
        first_request_time = Time.current - start_time

        # Second request should come from cache (much faster)
        start_time = Time.current
        discovery_doc2 = controller.send(:fetch_oidc_discovery_document, okta_test_issuer)
        second_request_time = Time.current - start_time

        # Validate both requests returned same data
        expect(discovery_doc1).to eq(discovery_doc2)

        # Cache should have Vulcan metadata in Rails.cache
        cache_key = "oidc_discovery:oidc_discovery:#{okta_test_issuer}"
        cached_data = Rails.cache.read(cache_key)
        expect(cached_data).to be_present
        expect(cached_data['vulcan_cache_version']).to eq('1.1')
        expect(cached_data['cached_at']).to be_present
        expect(cached_data['expires_at']).to be_present

        # Second request should be significantly faster (cached)
        expect(second_request_time).to be < (first_request_time * 0.1),
                                       'Second request should be much faster due to caching'

        Rails.logger.info 'Okta Discovery Performance:'
        Rails.logger.info "  First request (network): #{(first_request_time * 1000).round(2)}ms"
        Rails.logger.info "  Second request (cache): #{(second_request_time * 1000).round(2)}ms"
        Rails.logger.info "  Cache speedup: #{(first_request_time / second_request_time).round(1)}x"
      end

      it 'validates Okta discovery document structure matches our validation' do
        mock_oidc_settings(enabled: true, issuer: okta_test_issuer, discovery: true)

        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        discovery_doc = controller.send(:fetch_oidc_discovery_document, okta_test_issuer)

        # Test our validation logic against real Okta response
        expect do
          controller.send(:validate_discovery_document, discovery_doc, okta_test_issuer)
        end.not_to raise_error

        # Count endpoints using our helper
        endpoint_count = controller.send(:count_discovered_endpoints, discovery_doc)
        expect(endpoint_count).to be >= 4 # At minimum: auth, token, userinfo, jwks

        Rails.logger.info 'Okta Discovery Validation:'
        Rails.logger.info '  Validation: PASSED'
        Rails.logger.info "  Endpoints discovered: #{endpoint_count}"
        Rails.logger.info "  Document size: #{discovery_doc.to_json.length} bytes"
      end
    end

    context 'with Okta-specific URL patterns' do
      it 'handles Okta organization URLs correctly' do
        # Test Okta URL patterns (org URL or authorization server URL)
        org_issuer = okta_test_issuer

        # Accept either pattern: https://domain.okta.com OR https://domain.okta.com/oauth2/default
        expect(org_issuer).to match(%r{https://[^.]+\.okta\.com(/oauth2/\w+)?$})

        mock_oidc_settings(enabled: true, issuer: org_issuer, discovery: true)

        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        discovery_doc = controller.send(:fetch_oidc_discovery_document, org_issuer)
        expect(discovery_doc).to be_present
        expect(discovery_doc['issuer']).to eq(org_issuer)
      end

      it 'validates Okta URLs work with discovery regardless of pattern' do
        # Test that discovery works with any valid Okta URL pattern
        mock_oidc_settings(enabled: true, issuer: okta_test_issuer, discovery: true)

        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        discovery_doc = controller.send(:fetch_oidc_discovery_document, okta_test_issuer)
        expect(discovery_doc).to be_present
        expect(discovery_doc['issuer']).to eq(okta_test_issuer)

        # Log which pattern we're testing
        if okta_test_issuer.include?('/oauth2/')
          Rails.logger.info "✓ Testing authorization server URL pattern: #{okta_test_issuer}"
        else
          Rails.logger.info "✓ Testing organization URL pattern: #{okta_test_issuer}"
        end
      end
    end

    context 'Okta error handling and edge cases' do
      it 'handles non-existent Okta domain gracefully' do
        fake_issuer = 'https://nonexistent-domain-12345.okta.com'
        mock_oidc_settings(enabled: true, issuer: fake_issuer, discovery: true)

        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        # Should return nil for non-existent domain, not raise error
        discovery_doc = controller.send(:fetch_oidc_discovery_document, fake_issuer)
        expect(discovery_doc).to be_nil
      end

      it 'validates issuer mismatch detection with wrong Okta domain' do
        # Use a different valid Okta domain than configured
        wrong_issuer = 'https://dev-00000.okta.com' # Different from test issuer
        mock_oidc_settings(enabled: true, issuer: wrong_issuer, discovery: true)

        controller = SessionsController.new
        allow(controller).to receive(:session).and_return({})

        # This should fail due to issuer mismatch (if the test domain doesn't match)
        if wrong_issuer == okta_test_issuer
          skip 'Need different Okta domain for issuer mismatch test'
        else
          discovery_doc = controller.send(:fetch_oidc_discovery_document, wrong_issuer)
          expect(discovery_doc).to be_nil # Should fail validation
        end
      end
    end
  end

  # Helper method to mock OIDC settings
  def mock_oidc_settings(enabled: true, discovery: true, issuer: nil)
    oidc_settings = double('oidc_settings')
    allow(oidc_settings).to receive_messages(enabled: enabled, discovery: discovery)

    if enabled && issuer
      args_mock = double('args')
      allow(args_mock).to receive(:issuer).and_return(issuer)
      allow(oidc_settings).to receive(:args).and_return(args_mock)
    end

    allow(Settings).to receive(:oidc).and_return(oidc_settings)
  end
end
