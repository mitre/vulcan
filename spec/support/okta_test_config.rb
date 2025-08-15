# frozen_string_literal: true

# Okta Test Configuration Helper
#
# To run Okta integration tests, set environment variables:
#   OKTA_TEST_ISSUER=https://your-test-domain.okta.com
#   OKTA_TEST_CLIENT_ID=your_test_client_id  (optional, for full flow testing)
#   OKTA_TEST_CLIENT_SECRET=your_test_secret (optional, for full flow testing)
#
# Example:
#   export OKTA_TEST_ISSUER=https://dev-12345.okta.com
#   bundle exec rspec spec/integration/okta_discovery_integration_spec.rb

RSpec.configure do |config|
  # Skip Okta integration tests if not configured
  config.before(:each, :okta_integration) do
    if ENV['OKTA_TEST_ISSUER'].blank?
      skip <<~MESSAGE
        Okta integration tests require configuration.

        Set environment variables:
          export OKTA_TEST_ISSUER=https://your-test-domain.okta.com
        #{'  '}
        Then run:
          bundle exec rspec spec/integration/okta_discovery_integration_spec.rb
      MESSAGE
    end
  end

  # Helper to get Okta test configuration
  config.before(:each, :okta_integration) do
    @okta_test_config = {
      issuer: ENV.fetch('OKTA_TEST_ISSUER', nil),
      client_id: ENV.fetch('OKTA_TEST_CLIENT_ID', nil),
      client_secret: ENV.fetch('OKTA_TEST_CLIENT_SECRET', nil)
    }
  end
end

# Helper methods for OIDC testing
module OktaTestHelpers
  def okta_test_issuer
    ENV['VULCAN_OIDC_ISSUER_URL'] || ENV.fetch('OKTA_TEST_ISSUER', nil)
  end

  def oidc_enabled?
    ENV['VULCAN_ENABLE_OIDC'] == 'true'
  end

  def okta_test_configured?
    oidc_enabled? && okta_test_issuer.present?
  end

  def okta_discovery_url
    "#{okta_test_issuer}/.well-known/openid-configuration" if okta_test_issuer
  end

  def skip_unless_okta_configured
    return if okta_test_configured?

    skip 'OIDC not configured - set VULCAN_ENABLE_OIDC=true and VULCAN_OIDC_ISSUER_URL to run these tests'
  end
end

RSpec.configure do |config|
  config.include OktaTestHelpers, type: :feature
  config.include OktaTestHelpers, type: :integration
  config.include OktaTestHelpers, type: :system
end
