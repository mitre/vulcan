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

  describe 'OmniAuth login records the provider used for the session' do
    # OmniAuth test mode DOES drive the real callback controller via
    # post '/users/auth/<provider>' + follow_redirect!, so assert the behavior
    # directly. With multi-provider OIDC the callback sets session[:auth_method]
    # from auth.provider, which is the per-provider strategy name (:okta,
    # :login_gov, ...) — verified at the model level in user_multi_provider_spec.
    let(:user) { create(:user, provider: 'oidc', uid: 'oidc-session-uid') }

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(
        provider: 'oidc',
        uid: user.uid,
        info: { name: user.name, email: user.email },
        credentials: { id_token: 'fake-id-token' },
        extra: { raw_info: {} }
      )
    end

    after do
      OmniAuth.config.mock_auth[:oidc] = nil
      OmniAuth.config.test_mode = false
    end

    it 'sets session[:auth_method] to the provider name after the OIDC callback' do
      post '/users/auth/oidc'
      follow_redirect!

      expect(session[:auth_method]).to eq(:oidc)
    end
  end
end
