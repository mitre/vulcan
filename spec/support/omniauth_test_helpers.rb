# frozen_string_literal: true

module OmniauthTestHelpers
  # Mock Okta authentication response for the registry-registered :okta provider
  def mock_okta_auth(email: 'test@example.com', name: 'Test User', uid: 'okta-123',
                     id_token: 'fake-id-token', verified: true)
    OmniAuth.config.mock_auth[:okta] = OmniAuth::AuthHash.new({
                                                                provider: 'okta',
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
  def reset_okta_mock
    OmniAuth.config.mock_auth[:okta] = nil
    OmniAuth.config.test_mode = false
  end
end

RSpec.configure do |config|
  config.include OmniauthTestHelpers
end
