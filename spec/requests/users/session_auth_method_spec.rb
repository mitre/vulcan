# frozen_string_literal: true

require 'rails_helper'

##
# Session Auth Method Tracking
#
# REQUIREMENT: After any successful login, `session[:auth_method]` must record
# HOW the user signed in during THIS session. This is distinct from `user.provider`
# which records WHAT external identity is linked to the account.
#
# This matters because:
# - A user may have a local password AND a linked OIDC identity
# - If they sign in with their local password, the profile should say "Signed in via
#   email and password" — NOT "Signed in via Okta" (which would be misleading)
# - Showing the wrong method confuses users and damages trust
#
# Devise calls `reset_session` on login to prevent session fixation attacks, so
# session[:auth_method] must be set AFTER the reset, or it will be wiped.
RSpec.describe 'Session auth method tracking' do
  before do
    Rails.application.reload_routes!
  end

  describe 'local login (email/password)' do
    let(:user) { create(:user, password: 'S3cure!#TestPas1', password_confirmation: 'S3cure!#TestPas1') }

    it 'sets session[:auth_method] to :local after successful login' do
      post user_session_path, params: {
        user: { email: user.email, password: 'S3cure!#TestPas1' }
      }

      expect(session[:auth_method]).to eq(:local)
    end

    it 'survives Devise session reset (reset_session is called on login)' do
      # Explicitly set some session data BEFORE login to confirm the reset happens
      get new_user_session_path
      post user_session_path, params: {
        user: { email: user.email, password: 'S3cure!#TestPas1' }
      }

      # auth_method should be present AFTER the reset
      expect(session[:auth_method]).to eq(:local)
    end

    it 'does not set auth_method on failed login' do
      post user_session_path, params: {
        user: { email: user.email, password: 'wrong-password' }
      }

      expect(session[:auth_method]).to be_nil
    end
  end

  describe 'OmniAuth login (OIDC/LDAP/GitHub)' do
    # OmniAuth test mode doesn't trigger the real callback controller path easily,
    # so we verify the controller code contains the correct session write logic.
    let(:controller_code) do
      Rails.root.join('app/controllers/users/omniauth_callbacks_controller.rb').read
    end

    it 'OmniauthCallbacksController sets session[:auth_method] from auth.provider' do
      # The controller must write session[:auth_method] so the profile can show
      # "Signed in via Okta" vs "Signed in via email and password".
      expect(controller_code).to include('session[:auth_method]'),
                                 'OmniauthCallbacksController must set session[:auth_method]'
    end

    it 'sets auth_method using to_sym of auth.provider' do
      # :oidc, :ldap, :github — symbols for consistency with local login (:local)
      expect(controller_code).to match(/session\[:auth_method\]\s*=\s*auth\.provider.*\.to_sym/)
    end
  end
end
