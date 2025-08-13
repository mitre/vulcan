# frozen_string_literal: true

require 'rails_helper'

# Check if chromedriver is available
def chromedriver_available?
  return @chromedriver_available if defined?(@chromedriver_available)

  # Try to find chromedriver in PATH
  @chromedriver_available = system('which chromedriver > /dev/null 2>&1') ||
                            system('where chromedriver > /dev/null 2>&1')
end

# This test requires chromedriver to be installed for Selenium tests.
# If chromedriver is not available, the test will be skipped.
RSpec.describe 'Local Login', skip: (chromedriver_available? ? false : 'Chromedriver not installed'), type: :feature do
  LOCAL_LOGIN_TAB = 'Local Login' # rubocop:disable Lint/ConstantDefinitionInBlock
  include LoginHelpers

  before do
    stub_ldap_setting(enabled: true)
  end

  let(:user1) { create(:user) }

  context 'when user login is incorrect' do
    it 'shows an error banner and the login page again', skip: 'Flaky in CI - toast notification timing issue' do
      credentials = { 'user_email' => user1.email, 'user_password' => 'bad_pass' }
      expect { vulcan_sign_in_with(LOCAL_LOGIN_TAB, credentials) }
        .not_to change(user1, :sign_in_count)

      expect(page)
        .to have_selector('.b-toast-danger', text: 'Invalid Email or password.')

      # Expect the Local Login tab to be active on page reload
      expect(page.find('a', text: LOCAL_LOGIN_TAB)[:class]).to include('active')
    end
  end
end
