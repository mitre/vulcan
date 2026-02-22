# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (AC-12(02) / V-222392): The application must display an explicit
# logoff message to users indicating the reliable termination of authenticated
# communications sessions.
#
# Devise sets flash[:notice] to I18n.t('devise.sessions.signed_out') on logout.
# The Toaster Vue component (present on every page via application layout)
# receives flash notices as props and displays them client-side.
RSpec.describe 'Logout confirmation message' do
  before do
    Rails.application.reload_routes!
  end

  it 'sets a signed-out flash notice after logout' do
    user = create(:user)
    sign_in user

    # Verify we're logged in
    get '/projects'
    expect(response).to have_http_status(:success)

    # Log out (Devise uses DELETE for sign_out per best practices)
    delete destroy_user_session_path
    expect(response).to redirect_to(root_path)

    # Verify Devise sets the flash notice for the Toaster to display
    expect(flash[:notice]).to eq(I18n.t('devise.sessions.signed_out'))

    # Verify the flash is passed to the Toaster component as a prop in the layout
    follow_redirect! # root -> login (unauthenticated redirect)
    follow_redirect! # -> login page rendered
    # The layout passes notice as a Vue prop: 'v-bind:notice': notice.to_json
    expect(response.body).to include('v-bind:notice')
  end

  it 'invalidates the session so subsequent requests require login' do
    user = create(:user)
    sign_in user

    delete destroy_user_session_path

    # After logout, accessing a protected page should redirect to login
    get '/projects'
    expect(response).to redirect_to(new_user_session_path)
  end
end
