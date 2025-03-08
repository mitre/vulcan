# frozen_string_literal: true

require 'rails_helper'

# These tests validate LDAP login functionality using the bitnami/openldap container.
# The test environment is set up with bin/test-with-ldap script that:
# 1. Starts a database and LDAP server in Docker containers
# 2. Configures the right environment for the LDAP tests
# 3. Works on both Intel and M1/M2/M3 Macs
#
# The default LDAP user created in the container:
# - Username: zoidberg@planetexpress.com
# - Password: zoidberg
RSpec.describe 'Login with LDAP', type: :feature, skip: !Settings.ldap.enabled do
  include LoginHelpers

  before(:all) do
    puts "LDAP Config: #{Settings.ldap.servers.main.to_hash}"
  end

  context 'when ldap login is enabled' do
    it 'successfully logs an ldap user in with correct credentials' do
      # Debug information for troubleshooting
      puts "Settings.ldap.enabled: #{Settings.ldap.enabled}"
      puts "Testing login with: zoidberg@planetexpress.com / zoidberg"
      
      expect do
        visit new_user_session_path
        puts "Page HTML: #{page.html}"
        
        # Verify LDAP link is present
        expect(page).to have_link('LDAP')
        click_link 'LDAP'
        
        fill_in 'username', with: 'zoidberg@planetexpress.com'
        fill_in 'password', with: 'zoidberg'
        click_button 'Sign in'
      end.to change(User, :count).from(0).to(1)

      expect(page).to have_selector('.b-toast-success', text: I18n.t('devise.sessions.signed_in'))
    end

    it 'does not log an ldap user in with incorrect credentials' do
      expect do
        vulcan_sign_in_with('LDAP', { username: 'zoidberg@planetexpress.com', password: '!zoidberg' })
      end.not_to change(User, :count)

      expect(page)
        .to have_selector(
          '.b-toast-danger',
          text: 'Could not authenticate you from LDAP because "Invalid credentials".'
        )
    end
  end
end
