# frozen_string_literal: true

module LoginHelpers
  def stub_ldap_setting(messages)
    allow(Settings.ldap).to receive_messages(to_settings(messages))
  end

  def stub_local_login_setting(messages)
    allow(Settings.local_login).to receive_messages(to_settings(messages))
  end

  def stub_base_settings(messages)
    allow(Settings).to receive_messages(to_settings(messages))
  end

  def mock_omniauth_response(user, provider: 'ldap')
    # This sets up an object that is similar to what LDAP and GitHub return to
    # the User.from_omniauth method
    auth_hash = {
      info: {
        name: user.name,
        email: user.email
      },
      provider: provider,
      uid: FFaker::Random.rand(0...1_000_000).to_s,
      extra: {
        raw_info: {}
      },
      credentials: {}
    }

    # Add provider-specific structure
    case provider
    when 'ldap'
      auth_hash[:extra][:raw_info] = {
        mail: user.email
      }
    when 'oidc'
      auth_hash[:credentials][:id_token] = 'mock_id_token'
    end

    JSON.parse(auth_hash.to_json, object_class: OpenStruct)
  end

  def vulcan_sign_in_with(login_type, login_fields = {})
    visit new_user_session_path

    click_link login_type

    login_fields.each do |key, value|
      fill_in key, with: value
    end

    click_button 'Sign in'
  end
end
