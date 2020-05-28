# frozen_string_literal: true

module LoginHelpers
  def stub_ldap_setting(messages)
    allow(Settings.ldap).to receive_messages(to_settings(messages))
  end

  def stub_local_login_setting(messages)
    allow(Settings.local_login).to receive_messages(to_settings(messages))
  end

  def mock_omniauth_response(user)
    # This sets up an object that is similar to what LDAP and GitHub return to
    # the User.from_omniauth method
    JSON.parse({
      info: {
        name: user.name,
        email: user.email
      },
      provider: 'ldap',
      uid: FFaker::Random.rand(0...1_000_000)
    }.to_json, object_class: OpenStruct)
  end
end
