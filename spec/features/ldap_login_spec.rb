# frozen_string_literal: true

require 'rails_helper'

# These tests are skipped if LDAP is not enabled as part of the test suite.
# In order to run these tests set the `ENABLE_LDAP=true` environment variable
# and provide an appropriate LDAP server.
#
# This expects the rroemhild/test-openldap docker image to be running and the
# appropriate ENV's set so the application knows how to access the LDAP service
# running. in that container. See the Github Actions configuration
# for an example of how this works.
RSpec.describe 'Login with LDAP', type: :feature, skip: !Settings.ldap.enabled do
  include LoginHelpers

  context 'when ldap login is enabled' do
    it 'successfully logs an ldap user in with correct credentials' do
      expect do
        vulcan_sign_in_with('LDAP', { username: 'zoidberg@planetexpress.com', password: 'zoidberg' })
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
