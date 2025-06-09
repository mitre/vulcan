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
RSpec.describe 'Local Login', type: :feature, skip: (chromedriver_available? ? false : 'Chromedriver not installed') do
  LOCAL_LOGIN_TAB = 'Local Login' # rubocop:disable Lint/ConstantDefinitionInBlock
  include LoginHelpers

  before do
    stub_ldap_setting(enabled: true)
  end

  let(:user1) { create(:user) }

  context 'when user login is incorrect' do
    it 'shows an error banner and the login page again' do
      credentials = { 'user_email' => user1.email, 'user_password' => 'bad_pass' }
      expect { vulcan_sign_in_with(LOCAL_LOGIN_TAB, credentials) }
        .not_to change(user1, :sign_in_count)

      # Wait for the page to reload and the error message to appear
      expect(page)
        .to have_selector('.b-toast-danger', text: 'Invalid Email or password.')

      # Wait for the tabs to be rendered by Vue/Bootstrap-Vue
      expect(page).to have_selector('a', text: LOCAL_LOGIN_TAB, wait: 5)

      # After a failed login, the user should be able to try again
      # The test verifies that the login form remains functional after a failed attempt

      # The Local Login tab should still be clickable
      local_login_tab = page.find('a', text: LOCAL_LOGIN_TAB)
      expect(local_login_tab).to be_visible

      # Click the tab to ensure we can access the form
      local_login_tab.click

      # Verify the login form is displayed and functional
      within('#new_local_user') do
        # The email field should still contain the email we tried
        expect(page).to have_field('user_email', with: user1.email)
        expect(page).to have_field('user_password')

        # Verify we can submit the form again
        expect(page).to have_button('Sign in')
      end
    end
  end
end
