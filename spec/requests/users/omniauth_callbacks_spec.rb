# frozen_string_literal: true

require 'rails_helper'

##
# Tests for Remember Me functionality across login methods
#
# REQUIREMENTS:
# 1. Local login: When user checks "Remember Me", they should stay logged in
#    for 2 weeks (default remember_for period) even after session timeout
# 2. LDAP login: Same behavior as local login
# 3. Without Remember Me: Session expires after timeout_in period (60 minutes)
#
RSpec.describe 'Remember Me Functionality' do
  before do
    Rails.application.reload_routes!
  end

  describe 'Local Login with remember_me' do
    let(:user) { create(:user, password: 'S3cure!#TestPas1', password_confirmation: 'S3cure!#TestPas1') }

    context 'when remember_me is checked' do
      it 'sets remember_created_at on the user' do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'S3cure!#TestPas1',
            remember_me: '1'
          }
        }

        user.reload
        expect(user.remember_created_at).to be_present
      end

      it 'sets the remember_user_token cookie' do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'S3cure!#TestPas1',
            remember_me: '1'
          }
        }

        # Devise uses encrypted cookies - check the jar has the remember token
        expect(response.cookies['remember_user_token']).to be_present
      end
    end

    context 'when remember_me is not checked' do
      it 'does not set remember_created_at on the user' do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'S3cure!#TestPas1',
            remember_me: '0'
          }
        }

        user.reload
        expect(user.remember_created_at).to be_nil
      end

      it 'does not set the remember_user_token cookie' do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'S3cure!#TestPas1',
            remember_me: '0'
          }
        }

        expect(response.cookies['remember_user_token']).to be_nil
      end
    end
  end

  describe 'oauth_error handler security' do
    # The oauth_error handler catches Rack::OAuth2::Client::Error exceptions.
    # These exceptions can include sensitive details (token hints, client config,
    # redirect URIs). The flash message shown to users must NOT include
    # exception.message directly — only a generic error.

    it 'does not leak exception.message in flash alert' do
      controller_path = Rails.root.join('app/controllers/users/omniauth_callbacks_controller.rb')
      code = File.read(controller_path)

      # The oauth_error handler should NOT interpolate exception.message into flash
      oauth_error_method = code[/def oauth_error.*?(?=\n {4}def |\nend)/m]
      expect(oauth_error_method).not_to include("flash.alert = \"OAuth error: \#{exception.message}\""),
                                        'oauth_error leaks exception.message — use a generic message instead'
      expect(oauth_error_method).to include('flash.alert ='), 'oauth_error must set flash.alert'
    end
  end

  describe 'OmniAuth login with remember_me' do
    # The callback action is shared by every omniauth provider (LDAP, OIDC),
    # so the remember-me contract is driven through the provider registered
    # in the test environment. The remember cookie comes from
    # Devise::Controllers::Rememberable, which a callback controller must
    # include explicitly — it is opt-in, not part of DeviseController.
    let(:email) { 'omniauth-remember@example.com' }

    before do
      OmniAuth.config.test_mode = true
      mock_okta_auth(email: email, name: 'Remember Me User', uid: 'remember-123')
    end

    after { reset_okta_mock }

    context 'when remember_me is checked' do
      it 'signs the user in with the remember cookie set' do
        post user_oidc_omniauth_callback_path, params: { remember_me: '1' }

        expect(response).to redirect_to(root_path)
        expect(User.find_by(email: email).remember_created_at).to be_present
        expect(response.cookies['remember_user_token']).to be_present
      end
    end

    context 'when remember_me is not checked' do
      it 'signs the user in without the remember cookie' do
        post user_oidc_omniauth_callback_path

        expect(response).to redirect_to(root_path)
        expect(User.find_by(email: email).remember_created_at).to be_nil
        expect(response.cookies['remember_user_token']).to be_nil
      end
    end

    context 'when remember_me rides the provider round-trip as an authorize query param' do
      # OmniAuth stashes request.GET (query params only) into
      # session['omniauth.params'] during the request phase and restores it
      # at the callback — the delivery path for a checkbox that must survive
      # an external provider redirect.
      it 'signs the user in with the remember cookie set' do
        post user_oidc_omniauth_authorize_path(remember_me: '1')
        follow_redirect!

        expect(response).to redirect_to(root_path)
        expect(User.find_by(email: email).remember_created_at).to be_present
        expect(response.cookies['remember_user_token']).to be_present
      end
    end
  end

  describe 'failure reason wording' do
    # An unreachable or errored directory fails with the distinct
    # :ldap_error type (no longer reported as invalid credentials). The
    # raw type humanizes to the meaningless 'Ldap error' — known types get
    # a readable reason from devise.omniauth_callbacks.reasons instead,
    # and unknown types keep the humanized fallback.
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:oidc] = :ldap_error
    end

    after { reset_okta_mock }

    it 'explains an unreachable directory instead of echoing the error type' do
      post user_oidc_omniauth_authorize_path
      follow_redirect!

      expect(flash[:alert]).to include('could not be reached')
      expect(flash[:alert]).not_to include('Ldap error')
    end
  end
end
