# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (Finding 7): When a user is deleted from the database,
# their active session must be terminated. The next authenticated
# request should redirect to the login page instead of succeeding.
#
# Devise cookie-based sessions store the user ID. When the user record
# no longer exists, Devise's Warden strategy fails to deserialize
# the session, effectively invalidating it.
RSpec.describe 'Session invalidation on user deletion' do
  before do
    Rails.application.reload_routes!
  end

  it 'redirects to login after the user is deleted' do
    user = create(:user)
    sign_in user

    # Confirm authenticated access works before deletion
    get '/projects'
    expect(response).to have_http_status(:success)

    # Delete the user from the database
    user.destroy!

    # Next request should fail authentication and redirect to login
    get '/projects'
    expect(response).to redirect_to(new_user_session_path)
  end
end
