# frozen_string_literal: true

module OmniauthTestHelpers
  # The OIDC provider this test process actually booted with. Locally that is
  # whatever VULCAN_OIDC_PROVIDERS names (e.g. :okta); CI's legacy
  # single-provider env registers :oidc. Omniauth routes are fixed at boot, so
  # specs must drive the callback contract through a registered provider —
  # hardcoding one developer's provider name makes the suite env-dependent.
  def oidc_test_provider
    @oidc_test_provider ||= begin
      configured = Array(Settings.oidc&.providers).map { |provider| provider['name'].to_sym }
      provider = (configured & Devise.omniauth_providers).first
      skip 'No OIDC provider registered in this test environment' unless provider
      provider
    end
  end

  def oidc_callback_path
    public_send("user_#{oidc_test_provider}_omniauth_callback_path")
  end

  def oidc_authorize_path(**params)
    public_send("user_#{oidc_test_provider}_omniauth_authorize_path", **params)
  end

  # Mock a successful OIDC authentication for the registered provider
  def mock_oidc_auth(email: 'test@example.com', name: 'Test User', uid: 'oidc-123',
                     id_token: 'fake-id-token', verified: true)
    OmniAuth.config.mock_auth[oidc_test_provider] = OmniAuth::AuthHash.new({
                                                                             provider: oidc_test_provider.to_s,
                                                                             uid: uid,
                                                                             info: {
                                                                               email: email,
                                                                               name: name,
                                                                               email_verified: verified
                                                                             },
                                                                             credentials: {
                                                                               id_token: id_token,
                                                                               token: 'fake-access-token',
                                                                               expires_at: 1.hour.from_now.to_i
                                                                             },
                                                                             extra: {
                                                                               raw_info: {
                                                                                 sub: uid,
                                                                                 email: email,
                                                                                 email_verified: verified,
                                                                                 name: name
                                                                               }
                                                                             }
                                                                           })
  end

  # Reset OmniAuth configuration after tests
  def reset_oidc_mock
    OmniAuth.config.mock_auth[@oidc_test_provider] = nil if @oidc_test_provider
    OmniAuth.config.test_mode = false
  end
end

RSpec.configure do |config|
  config.include OmniauthTestHelpers
end
