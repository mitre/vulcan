# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Auth' do
  include LoginHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user, email: 'test@example.com', password: 'S3cure!#Pass999') }

  describe 'GET /api/auth/me' do
    context 'when authenticated' do
      before { sign_in user }

      it 'returns current user identity with admin status' do
        get '/api/auth/me', as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['id']).to eq(user.id)
        expect(body['name']).to eq(user.name)
        expect(body['email']).to eq(user.email)
        expect(body['admin']).to be(false)
      end

      it 'returns admin=true for admin users' do
        sign_in anchor_admin
        get '/api/auth/me', as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['admin']).to be(true)
      end

      it 'does NOT include sensitive fields (encrypted_password, reset_password_token)' do
        get '/api/auth/me', as: :json

        body = response.parsed_body
        expect(body).not_to have_key('encrypted_password')
        expect(body).not_to have_key('reset_password_token')
        expect(body).not_to have_key('confirmation_token')
      end
    end

    context 'when not authenticated' do
      # The 401 is an RFC 9457 problem body saying WHY and HOW to
      # authenticate — canonical field-by-field pins live in
      # error_rendering_spec; this pins the endpoint serves that contract.
      it 'returns the not_authenticated problem body' do
        get '/api/auth/me', as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response.media_type).to eq('application/problem+json')
        body = response.parsed_body
        expect(body['type']).to eq('/docs/api/errors#not_authenticated')
        expect(body['title']).to eq('Not authenticated')
        expect(body['how_to_authenticate']).to include('session', 'token')
      end
    end
  end

  describe 'POST /api/auth/login' do
    it 'authenticates with valid email and password' do
      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['id']).to eq(user.id)
      expect(body['name']).to eq(user.name)
      expect(body['email']).to eq(user.email)
    end

    it 'returns 401 for invalid credentials' do
      post '/api/auth/login', params: { email: user.email, password: 'wrong' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['type']).to eq('/docs/api/errors#invalid_credentials')
    end

    it 'returns 401 for non-existent email' do
      post '/api/auth/login', params: { email: 'nobody@example.com', password: 'anything' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'sets a session so subsequent /me calls succeed' do
      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json
      expect(response).to have_http_status(:ok)

      get '/api/auth/me', as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(user.id)
    end

    # Devise resets the CSRF token in a Warden after_authentication hook,
    # which runs only when the sign-in is recorded as an authentication
    # event. Without the reset, a token obtained before sign-in stays valid
    # for the signed-in session (CSRF token fixation).
    it 'rotates the session CSRF token on sign-in' do
      get '/api/auth/csrf', as: :json
      pre_login_token = session[:_csrf_token]
      expect(pre_login_token).to be_present

      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json
      expect(response).to have_http_status(:ok)

      get '/api/auth/csrf', as: :json
      expect(session[:_csrf_token]).to be_present
      expect(session[:_csrf_token]).not_to eq(pre_login_token)
    end

    # Local users below (never the shared let_it_be) — these mutate
    # failed_attempts / locked_at, which must not bleed across examples.

    it 'refuses a locked account even with the correct password (STIG AC-07)' do
      locked = create(:user, password: 'S3cure!#Pass999')
      locked.lock_access!

      post '/api/auth/login', params: { email: locked.email, password: 'S3cure!#Pass999' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['type']).to eq('/docs/api/errors#account_locked')

      # The correct-but-locked attempt established no session.
      get '/api/auth/me', as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'increments failed_attempts on a wrong password so lockout can trigger' do
      target = create(:user, password: 'S3cure!#Pass999')

      expect do
        post '/api/auth/login', params: { email: target.email, password: 'not-it' }, as: :json
      end.to change { target.reload.failed_attempts }.by(1)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['type']).to eq('/docs/api/errors#invalid_credentials')
    end

    context 'when local login is disabled (SSO-only instance)' do
      before { stub_local_login_setting(enabled: false) }

      it 'refuses the login with 403 before verifying the password' do
        post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['type']).to eq('/docs/api/errors#local_login_disabled')

        # No session was established.
        get '/api/auth/me', as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/auth/logout' do
    before { sign_in user }

    it 'destroys the session and returns 200' do
      delete '/api/auth/logout', as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['message']).to include('Signed out')
    end

    it 'subsequent /me call returns 401' do
      delete '/api/auth/logout', as: :json
      expect(response).to have_http_status(:ok)

      get '/api/auth/me', as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # GET /api/auth/csrf needs no sign-in, so a caller whose session has ended
  # (timed out, or superseded by a newer sign-in) gets a token on the first
  # call and can sign in again on the first attempt. Endpoints that need a
  # sign-in still answer 401 session_timed_out.
  describe 'after the session ends' do
    include ActiveSupport::Testing::TimeHelpers

    let(:credentials) { { email: user.email, password: 'S3cure!#Pass999' } }

    def sign_in_by_api
      post '/api/auth/login', params: credentials, as: :json
    end

    context 'when it timed out' do
      before do
        sign_in_by_api
        travel Devise.timeout_in + 1.minute
      end

      it 'issues a token on the first GET /api/auth/csrf' do
        get '/api/auth/csrf', as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['csrf_token']).to be_present
      end

      it 'issues a token on the first call from a browser that sends Accept: text/html' do
        get '/api/auth/csrf', headers: { 'Accept' => 'text/html' }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['csrf_token']).to be_present
      end

      it 'signs in again on the first POST /api/auth/login' do
        sign_in_by_api

        expect(response).to have_http_status(:ok)
        get '/api/auth/me', as: :json
        expect(response.parsed_body['id']).to eq(user.id)
      end

      # A client that posts JSON with no Accept header (or Accept: */*)
      # resolves to the HTML format, and the devise-security callbacks act on
      # exactly that format: they look the signed-in user up, so the timed-out
      # session's fetch hook signs the caller out and throws, and the login is
      # answered by the failure app instead of establishing a session. The
      # example above sends `as: :json`, which sets Accept and hides this.
      it 'signs in again on the first POST /api/auth/login sent without an Accept header' do
        post '/api/auth/login', params: credentials.to_json,
                                headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['id']).to eq(user.id)
      end

      it 'signs out with 200 on DELETE /api/auth/logout, as the HTML sign-out does' do
        delete '/api/auth/logout', as: :json

        expect(response).to have_http_status(:ok)
        get '/api/auth/me', as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it 'still answers an endpoint that needs a sign-in with 401 session_timed_out' do
        get '/api/auth/me', as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['type']).to eq('/docs/api/errors#session_timed_out')
      end
    end

    context 'when a newer sign-in superseded it' do
      let(:newer) { open_session }

      before do
        sign_in_by_api
        newer.post '/api/auth/login', params: credentials, as: :json
      end

      it 'issues a token on the first GET /api/auth/csrf' do
        expect(newer.response).to have_http_status(:ok)

        get '/api/auth/csrf', as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['csrf_token']).to be_present
      end

      it 'issues a token on the first call from a browser that sends Accept: text/html' do
        expect(newer.response).to have_http_status(:ok)

        get '/api/auth/csrf', headers: { 'Accept' => 'text/html' }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['csrf_token']).to be_present
      end
    end
  end

  # A sign-in must hand the new user a session of their own. The sharp edge is
  # the OIDC id_token: SessionsController#destroy sends session[:id_token] to
  # the provider as id_token_hint, so a token the previous occupant left
  # behind would travel in a logout the NEW user performs. The AC-8 consent
  # acknowledgment is the previous occupant's too, and must not excuse the new
  # user from the banner. Devise's require_no_authentication keeps the HTML
  # sign-in anonymous, so only this endpoint can be reached this way.
  describe 'POST /api/auth/login into a session another user already owns' do
    let(:provider) { oidc_test_provider }
    let(:previous_user) { create(:user, provider: provider.to_s, uid: 'okta-previous-occupant') }

    after { reset_oidc_mock }

    def sign_in_previous_user_via_oidc
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
        provider: provider.to_s, uid: previous_user.uid,
        info: { name: previous_user.name, email: previous_user.email },
        credentials: { id_token: 'previous-occupant-id-token' }, extra: { raw_info: {} }
      )
      post "/users/auth/#{provider}"
      follow_redirect!
    end

    it 'does not leave the previous user OIDC id_token in the new user session' do
      sign_in_previous_user_via_oidc
      expect(session[:id_token]).to eq('previous-occupant-id-token')

      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(session[:id_token]).to be_nil
    end

    # The consequence the leak produces: the new user's sign-out would be
    # redirected to the provider carrying the PREVIOUS user's id_token_hint.
    it 'does not send the new user sign-out to the provider with the previous user id_token' do
      # Discovery off, so the Okta-shaped fallback logout URL is built from
      # the configured issuer without reaching the network.
      allow(Settings.oidc).to receive(:discovery).and_return(false)
      sign_in_previous_user_via_oidc
      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json
      expect(response).to have_http_status(:ok)

      delete '/users/sign_out'

      expect(response.location.to_s).not_to include('id_token_hint')
      expect(response).to redirect_to(new_user_session_path)
    end

    # AC-8: the banner is acknowledged per session occupant. An
    # acknowledgment made by the previous user is not the new user's.
    it 'does not carry the previous user consent acknowledgment to the new user' do
      sign_in_previous_user_via_oidc
      post '/consent/acknowledge'
      expect(session[:consent_acknowledged_at]).to be_present

      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(session[:consent_acknowledged_at]).to be_nil
    end

    it 'signs the new user in, so the endpoint still does its job' do
      sign_in_previous_user_via_oidc

      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json

      expect(response.parsed_body['id']).to eq(user.id)
      get '/api/auth/me', as: :json
      expect(response.parsed_body['id']).to eq(user.id)
    end
  end

  describe 'DELETE /api/auth/logout after a password sign-in' do
    # Same reset as the HTML sign-out: the whole session goes, including the
    # authenticity token, auth_method and the consent acknowledgment.
    it 'resets the whole session' do
      post '/consent/acknowledge'
      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json
      get '/api/auth/csrf', as: :json
      expect(session[:_csrf_token]).to be_present
      expect(session[:auth_method]).to be_present
      expect(session[:consent_acknowledged_at]).to be_present
      session_cookie_before = cookies['_vulcan_session']

      delete '/api/auth/logout', as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['Set-Cookie']).to include('_vulcan_session=')
      expect(cookies['_vulcan_session']).not_to eq(session_cookie_before)
      expect(session[:_csrf_token]).to be_nil
      expect(session[:auth_method]).to be_nil
      expect(session[:consent_acknowledged_at]).to be_nil
    end
  end
end
