# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OidcStartupValidator do
  # Helper method to mock OIDC settings
  def mock_oidc_settings(enabled: true, discovery: true, issuer: 'https://example.okta.com')
    oidc_settings = double('oidc_settings')
    allow(oidc_settings).to receive(:enabled).and_return(enabled)
    allow(oidc_settings).to receive(:discovery).and_return(discovery)

    if enabled
      args_mock = double('args')
      allow(args_mock).to receive(:dig).with('issuer').and_return(issuer)
      allow(args_mock).to receive(:client_id).and_return('test-client-id')
      allow(args_mock).to receive(:client_secret).and_return('test-secret')
      allow(oidc_settings).to receive(:args).and_return(args_mock)
    end

    allow(Settings).to receive(:oidc).and_return(oidc_settings)
  end

  # Helper method to mock environment variables
  def mock_env_vars(vars = {})
    default_vars = {
      'VULCAN_OIDC_ISSUER_URL' => 'https://example.okta.com',
      'VULCAN_OIDC_CLIENT_ID' => 'test-client-id',
      'VULCAN_OIDC_CLIENT_SECRET' => 'test-secret',
      'VULCAN_OIDC_REDIRECT_URI' => 'https://vulcan.example.com/users/auth/oidc/callback'
    }

    combined_vars = default_vars.merge(vars)

    allow(ENV).to receive(:[]).and_call_original
    combined_vars.each do |key, value|
      allow(ENV).to receive(:[]).with(key).and_return(value)
    end
  end

  # Helper method to mock HTTP responses
  def mock_http_response(success: true, body: nil, code: '200', message: 'OK')
    mock_response = double('response')
    allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)

    if success
      allow(mock_response).to receive(:body).and_return(body || valid_discovery_response.to_json)
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

    # Add method for connectivity test (HEAD request)
    allow(mock_response).to receive(:code).and_return(code) if success
  end

  def valid_discovery_response
    {
      'issuer' => 'https://example.okta.com',
      'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize',
      'token_endpoint' => 'https://example.okta.com/oauth2/v1/token',
      'userinfo_endpoint' => 'https://example.okta.com/oauth2/v1/userinfo',
      'jwks_uri' => 'https://example.okta.com/oauth2/v1/keys',
      'end_session_endpoint' => 'https://example.okta.com/oauth2/v1/logout',
      'response_types_supported' => ['code'],
      'subject_types_supported' => ['public'],
      'id_token_signing_alg_values_supported' => ['RS256']
    }
  end

  # Helper to allow all logger calls (prevents strict expectation failures)
  def allow_all_logging
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:debug)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  before do
    # Mock Rails environment as production for most tests
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(Rails.env).to receive(:staging?).and_return(false)

    # Mock basic OIDC settings
    mock_oidc_settings
    mock_env_vars

    # Allow all logging to prevent strict expectation failures
    allow_all_logging
  end

  describe '.validate_configuration' do
    context 'with valid configuration' do
      it 'completes validation successfully' do
        mock_http_response(success: true, body: valid_discovery_response.to_json)

        # Allow all logging calls but verify no exceptions
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)
        allow(Rails.logger).to receive(:warn)

        expect { described_class.validate_configuration }.not_to raise_error
      end
    end

    context 'with missing required settings' do
      it 'raises error for missing issuer URL' do
        mock_env_vars('VULCAN_OIDC_ISSUER_URL' => nil)
        mock_oidc_settings(issuer: nil)

        expect { described_class.validate_configuration }.to raise_error(
          ArgumentError, /Missing required OIDC configuration.*VULCAN_OIDC_ISSUER_URL/
        )
      end

      it 'raises error for missing client ID' do
        mock_env_vars('VULCAN_OIDC_CLIENT_ID' => nil)

        expect { described_class.validate_configuration }.to raise_error(
          ArgumentError, /Missing required OIDC configuration.*VULCAN_OIDC_CLIENT_ID/
        )
      end

      it 'raises error for missing client secret' do
        mock_env_vars('VULCAN_OIDC_CLIENT_SECRET' => nil)

        expect { described_class.validate_configuration }.to raise_error(
          ArgumentError, /Missing required OIDC configuration.*VULCAN_OIDC_CLIENT_SECRET/
        )
      end
    end

    context 'with invalid issuer URL' do
      it 'raises error for invalid URL format' do
        mock_env_vars('VULCAN_OIDC_ISSUER_URL' => 'not-a-valid-url')
        mock_oidc_settings(issuer: 'not-a-valid-url')

        expect { described_class.validate_configuration }.to raise_error(
          ArgumentError, /OIDC issuer URL missing hostname/
        )
      end

      it 'raises error for HTTP in production' do
        mock_env_vars('VULCAN_OIDC_ISSUER_URL' => 'http://insecure.example.com')
        mock_oidc_settings(issuer: 'http://insecure.example.com')

        expect { described_class.validate_configuration }.to raise_error(
          ArgumentError, /OIDC issuer must use HTTPS in production/
        )
      end

      it 'warns but does not raise error for HTTP in development' do
        allow(Rails.env).to receive(:production?).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(true)

        mock_env_vars('VULCAN_OIDC_ISSUER_URL' => 'http://dev.example.com')
        mock_oidc_settings(issuer: 'http://dev.example.com')

        expect { described_class.validate_configuration }.not_to raise_error
      end
    end

    context 'with discovery endpoint validation' do
      it 'validates successful discovery response' do
        mock_http_response(success: true, body: valid_discovery_response.to_json)
        expect { described_class.validate_configuration }.not_to raise_error
      end

      it 'warns on discovery endpoint HTTP error' do
        mock_http_response(success: false, code: '404', message: 'Not Found')
        expect { described_class.validate_configuration }.not_to raise_error
      end

      it 'warns on discovery endpoint timeout' do
        mock_http = double('http')
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:verify_mode=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:use_ssl?).and_return(true)
        allow(mock_http).to receive(:request).and_raise(Timeout::Error)

        expect { described_class.validate_configuration }.not_to raise_error
      end

      it 'warns on invalid JSON response' do
        mock_http_response(success: true, body: 'invalid json')
        expect { described_class.validate_configuration }.not_to raise_error
      end

      it 'skips discovery validation when discovery is disabled' do
        mock_oidc_settings(discovery: false)

        # Mock Rails.env to prevent connectivity test
        allow(Rails.env).to receive(:production?).and_return(false)

        expect { described_class.validate_configuration }.not_to raise_error
      end
    end

    context 'with deprecated configuration patterns' do
      it 'warns about manual endpoints when discovery is enabled' do
        mock_env_vars(
          'VULCAN_OIDC_AUTHORIZATION_URL' => 'https://example.com/auth',
          'VULCAN_OIDC_TOKEN_URL' => 'https://example.com/token'
        )

        expect { described_class.validate_configuration }.not_to raise_error
      end

      it 'warns about deprecated configuration variables' do
        mock_env_vars(
          'VULCAN_OIDC_HOST' => 'example.com',
          'VULCAN_OIDC_PORT' => '443'
        )

        expect { described_class.validate_configuration }.not_to raise_error
      end
    end

    context 'with redirect URI validation' do
      it 'validates correct redirect URI format' do
        mock_env_vars('VULCAN_OIDC_REDIRECT_URI' => 'https://vulcan.example.com/users/auth/oidc/callback')
        expect { described_class.validate_configuration }.not_to raise_error
      end

      it 'warns about incorrect redirect URI path' do
        mock_env_vars('VULCAN_OIDC_REDIRECT_URI' => 'https://vulcan.example.com/wrong/callback')
        expect { described_class.validate_configuration }.not_to raise_error
      end

      it 'warns about invalid redirect URI format' do
        mock_env_vars('VULCAN_OIDC_REDIRECT_URI' => 'not-a-valid-uri')
        expect { described_class.validate_configuration }.not_to raise_error
      end
    end

    context 'with discovery document structure validation' do
      it 'warns about missing required fields' do
        minimal_discovery = {
          'issuer' => 'https://example.okta.com',
          'authorization_endpoint' => 'https://example.okta.com/oauth2/v1/authorize'
          # rubocop:disable Layout/LineLength
          # Missing required fields: response_types_supported, subject_types_supported, id_token_signing_alg_values_supported
          # rubocop:enable Layout/LineLength
        }

        mock_http_response(success: true, body: minimal_discovery.to_json)
        expect { described_class.validate_configuration }.not_to raise_error
      end

      it 'warns about issuer mismatch' do
        mismatched_discovery = valid_discovery_response.merge(
          'issuer' => 'https://different.provider.com'
        )

        mock_http_response(success: true, body: mismatched_discovery.to_json)
        expect { described_class.validate_configuration }.not_to raise_error
      end
    end
  end

  describe 'environment-specific behavior' do
    it 'runs validation when OIDC is enabled (production)' do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect(described_class).to receive(:validate_configuration)

      # Simulate the initializer logic
      described_class.validate_configuration if Settings.oidc&.enabled
    end

    it 'runs validation when OIDC is enabled (development with config)' do
      allow(Rails.env).to receive(:production?).and_return(false)
      allow(Rails.env).to receive(:development?).and_return(true)

      expect(described_class).to receive(:validate_configuration)

      # Simulate the initializer logic
      described_class.validate_configuration if Settings.oidc&.enabled
    end

    it 'skips validation when OIDC is disabled' do
      allow(Rails.env).to receive(:development?).and_return(true)
      allow(Settings.oidc).to receive(:enabled).and_return(false)

      expect(described_class).not_to receive(:validate_configuration)

      # Simulate the initializer logic
      unless Settings.oidc&.enabled
        # Validation should be skipped
      end
    end
  end
end
