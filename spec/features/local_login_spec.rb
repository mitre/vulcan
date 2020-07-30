# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Local Login', type: :feature do
  include LoginHelpers

  context 'when user login is incorrect' do
    let(:user) { create(:user) }

    it 'shows error banner when login credentials are incorrect' do
      credentials = { 'user_email' => user.email, 'user_password' => 'bad_pass' }
      expect { vulcan_sign_in_with('Local Login', credentials) }
        .not_to change(User, :count)

      expect(page)
        .to have_selector('.alert-danger', text: 'Invalid Email or password.')
    end
  end
end
