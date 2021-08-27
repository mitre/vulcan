# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Local Login', type: :feature do
  include LoginHelpers

  before do
    stub_ldap_setting(enabled: true)
  end

  let(:user1) { create(:user) }

  context 'when user login is incorrect' do
    it 'shows an error banner and the login page again' do
      credentials = { 'user_email' => user1.email, 'user_password' => 'bad_pass' }
      expect { vulcan_sign_in_with('Local Login', credentials) }
        .not_to change(user1, :sign_in_count)

      expect(page)
        .to have_selector('.b-toast-danger', text: 'Invalid Email or password.')

      # Expect the Local Login tab to be active on page reload
      expect(page.find('a', text: 'Local Login')[:class]).to include('active')
    end
  end
end
