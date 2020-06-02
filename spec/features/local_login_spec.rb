# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Local Login', type: :feature do
  include LoginHelpers

  let(:user1) { create(:user) }

  context 'when user login is incorrect' do
    it 'shows error banner when login credentials are incorrect' do
      credentials = { 'user_email' => user1.email, 'user_password' => 'bad_pass' }
      expect { vulcan_sign_in_with('Local Login', credentials) }
        .not_to change(user1, :sign_in_count)

      expect(page)
        .to have_selector('.alert-danger', text: 'Invalid Email or password.')
    end
  end
end
