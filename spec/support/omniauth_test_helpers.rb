# frozen_string_literal: true

module OmniauthTestHelpers
  # Mock OKTA/OIDC authentication response
  def mock_okta_auth(email: 'test@example.com', name: 'Test User', uid: 'okta-123', 
                     id_token: 'fake-id-token', verified: true)
    OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new({
      provider: 'oidc',
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

  # Mock failed authentication
  def mock_okta_auth_failure(message = 'Authentication failed')
    OmniAuth.config.mock_auth[:oidc] = :invalid_credentials
    OmniAuth.config.on_failure = Proc.new { |env|
      OmniAuth::FailureEndpoint.new(env).redirect_to_failure
    }
  end

  # Reset OmniAuth configuration after tests
  def reset_okta_mock
    OmniAuth.config.mock_auth[:oidc] = nil
    OmniAuth.config.test_mode = false
  end

  # Helper to sign in via OKTA in integration tests
  def okta_sign_in(user_attributes = {})
    mock_okta_auth(**user_attributes)
    visit '/users/auth/oidc'
    # OmniAuth test mode will automatically redirect to callback
  end
end

RSpec.configure do |config|
  config.include OmniauthTestHelpers
end