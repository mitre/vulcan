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

    # Log out (Devise uses DELETE for sign_out per best practices).
    # after_sign_out_path_for sends us STRAIGHT to the sign-in page —
    # flash survives exactly one redirect, so a second (auth) redirect
    # through root would consume the notice before anything rendered.
    # The pre-fix version of this test followed TWO redirects and only
    # checked that the prop NAME existed, which passed while the message
    # itself was lost — the assertion below pins the rendered VALUE.
    delete destroy_user_session_path
    expect(response).to redirect_to(new_user_session_path)

    # Verify Devise sets the flash notice for the Toaster to display
    expect(flash[:notice]).to eq(I18n.t('devise.sessions.signed_out'))

    # Verify the message itself reaches the rendered page as the Toaster's
    # notice prop ('v-bind:notice': notice.to_json in the layout).
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('v-bind:notice')
    expect(response.body).to include('Signed out successfully.')
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
