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

  def vulcan_sign_in_with(username, password, login_field = 'Local Login')
    visit new_user_session_path

    click_link login_field

    fill_in 'username', with: username
    fill_in 'password', with: password

    click_button 'Sign in'
  end

  def vulcan_sign_in(hash={}, login_field = 'Local Login')
    visit new_user_session_path

    click_link login_field
    
    fill_in 'user_email', with: hash.fetch('email')
    fill_in 'user_password', with: hash.fetch('password')

    click_button 'Sign in'
  end
end
