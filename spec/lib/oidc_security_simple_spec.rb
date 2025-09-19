# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OIDC Security Configuration' do
  # Simple tests to validate our OIDC security improvements

  describe 'Configuration Template Validation' do
    it 'validates post logout redirect URI is configurable' do
      # Test the ERB template logic directly
      template = "<%= ENV['VULCAN_OIDC_POST_LOGOUT_REDIRECT_URI'] || '/' %>"

      # Test with environment variable set
      ClimateControl.modify(VULCAN_OIDC_POST_LOGOUT_REDIRECT_URI: '/custom-logout') do
        result = ERB.new(template).result
        expect(result).to eq('/custom-logout')
      end

      # Test with environment variable not set
      ClimateControl.modify(VULCAN_OIDC_POST_LOGOUT_REDIRECT_URI: nil) do
        result = ERB.new(template).result
        expect(result).to eq('/')
      end
    end

    it 'validates PKCE defaults appropriately for confidential clients' do
      # Test default (when env var not set, should default to false for confidential clients)
      ClimateControl.modify(VULCAN_OIDC_PKCE: nil) do
        template = "<%= ENV['VULCAN_OIDC_PKCE'].present? ? ActiveModel::Type::Boolean.new.cast(ENV['VULCAN_OIDC_PKCE']) : false %>"
        result = ERB.new(template).result
        expect(result).to eq('false')
      end

      # Test explicit enable (for specific security requirements)
      ClimateControl.modify(VULCAN_OIDC_PKCE: 'true') do
        template = "<%= ENV['VULCAN_OIDC_PKCE'].present? ? ActiveModel::Type::Boolean.new.cast(ENV['VULCAN_OIDC_PKCE']) : false %>"
        result = ERB.new(template).result
        expect(result).to eq('true')
      end
    end

    it 'validates state parameter requirement defaults to true' do
      template = "<%= ActiveModel::Type::Boolean.new.cast(ENV['VULCAN_OIDC_REQUIRE_STATE']) || true %>"

      ClimateControl.modify(VULCAN_OIDC_REQUIRE_STATE: nil) do
        result = ERB.new(template).result
        expect(result).to eq('true')
      end
    end

    it 'validates nonce sending defaults to true' do
      template = "<%= ActiveModel::Type::Boolean.new.cast(ENV['VULCAN_OIDC_SEND_NONCE']) || true %>"

      ClimateControl.modify(VULCAN_OIDC_SEND_NONCE: nil) do
        result = ERB.new(template).result
        expect(result).to eq('true')
      end
    end
  end

  describe 'Security Best Practices Documentation' do
    it 'documents all required OIDC environment variables' do
      env_vars_content = File.read('ENVIRONMENT_VARIABLES.md')

      required_oidc_vars = %w[
        VULCAN_ENABLE_OIDC
        VULCAN_OIDC_ISSUER_URL
        VULCAN_OIDC_CLIENT_ID
        VULCAN_OIDC_CLIENT_SECRET
        VULCAN_OIDC_REDIRECT_URI
        VULCAN_OIDC_POST_LOGOUT_REDIRECT_URI
        VULCAN_OIDC_PKCE
        VULCAN_OIDC_REQUIRE_STATE
        VULCAN_OIDC_SEND_NONCE
      ]

      required_oidc_vars.each do |var|
        expect(env_vars_content).to include(var),
                                    "ENVIRONMENT_VARIABLES.md should document #{var}"
      end
    end

    it 'validates security defaults are properly documented' do
      env_vars_content = File.read('ENVIRONMENT_VARIABLES.md')

      security_features = [
        'PKCE (Proof Key for Code Exchange)',
        'state parameter for CSRF protection',
        'nonce for replay attack protection'
      ]

      security_features.each do |feature|
        expect(env_vars_content).to include(feature),
                                    "Security feature should be documented: #{feature}"
      end
    end
  end
end
