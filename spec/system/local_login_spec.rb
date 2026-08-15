# frozen_string_literal: true

require 'rails_helper'

# Environment precondition: Selenium needs a Chrome build to drive.
# Selenium Manager (bundled with selenium-webdriver >= 4.6) provisions the
# matching chromedriver automatically whenever Chrome is installed, so the
# gate probes for the BROWSER — a PATH chromedriver still counts for
# environments that pin their own driver. Probing only the PATH was a
# false negative that muted this file on Selenium-Manager-capable machines.
def browser_automation_available?
  return @browser_automation_available if defined?(@browser_automation_available)

  @browser_automation_available =
    system('which chromedriver > /dev/null 2>&1') ||
    system('where chromedriver > /dev/null 2>&1') ||
    File.exist?('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome') ||
    %w[google-chrome google-chrome-stable chromium chromium-browser].any? do |browser|
      system("which #{browser} > /dev/null 2>&1")
    end
end

# This test requires a drivable Chrome; without one the file is skipped.
RSpec.describe 'Local Login', skip: (browser_automation_available? ? false : 'No Chrome or chromedriver available') do
  LOCAL_LOGIN_TAB = 'Local Login' # rubocop:disable Lint/ConstantDefinitionInBlock
  include LoginHelpers

  before do
    stub_ldap_setting(enabled: true)
  end

  let(:user1) { create(:user) }

  context 'when user login is incorrect' do
    it 'shows an error banner and the login page again' do
      credentials = { 'user_email' => user1.email, 'user_password' => 'bad_pass' }
      # reload inside the block: the bare change(user1, :sign_in_count) form
      # re-read the same in-memory object and could never observe the
      # server's write — it passed regardless of what the app did.
      expect { vulcan_sign_in_with(LOCAL_LOGIN_TAB, credentials) }
        .not_to(change { user1.reload.sign_in_count })

      # The app renders Devise's failure message with a lowercase
      # authentication key ("Invalid email or password."). The old
      # capital-E expectation failed deterministically — the recorded
      # "flaky toast timing" was a misdiagnosis of a text mismatch.
      expect(page)
        .to have_css('.b-toast-danger', text: 'Invalid email or password.')

      # Expect the Local Login tab to be active on page reload
      expect(page.find('a', text: LOCAL_LOGIN_TAB)[:class]).to include('active')
    end
  end
end
