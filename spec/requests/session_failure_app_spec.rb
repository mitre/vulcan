# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (docs/decisions/adr-api-error-envelope.md §3): when warden throws
# during a request (evicted session, timeout, plain unauthenticated), the
# custom Devise failure app answers JSON/non-navigational requests with the
# RFC 9457 problem envelope naming the TRUE cause, while HTML/navigational
# requests keep Devise's redirect + flash byte-identical.
RSpec.describe 'Session-aware Devise failure app' do
  before { Rails.application.reload_routes! }

  describe 'cause → problem-document mapping (SessionAwareFailureApp.problem_for)' do
    it 'reports a superseded session definitively' do
      doc = SessionAwareFailureApp.problem_for(:session_limited)
      expect(doc[:type]).to eq('/api/docs/errors#session_superseded')
      expect(doc[:title]).to eq('Session ended — signed in elsewhere')
      expect(doc[:status]).to eq(401)
      expect(doc[:detail]).to eq(
        'You were signed out because this account signed in from another location. ' \
        'Only one active session per account is allowed at a time.'
      )
      expect(doc[:how_to_authenticate]).to eq(ErrorRendering::HOW_TO_AUTHENTICATE)
    end

    it 'reports a timed-out session' do
      doc = SessionAwareFailureApp.problem_for(:timeout)
      expect(doc[:type]).to eq('/api/docs/errors#session_timed_out')
      expect(doc[:title]).to eq('Session timed out')
      expect(doc[:detail]).to eq('Your session timed out after a period of inactivity. Sign in again to continue.')
      expect(doc[:how_to_authenticate]).to eq(ErrorRendering::HOW_TO_AUTHENTICATE)
    end

    it 'falls back to the shared not-authenticated body for a generic cause' do
      doc = SessionAwareFailureApp.problem_for(:unauthenticated)
      expect(doc[:type]).to eq('/api/docs/errors#not_authenticated')
      expect(doc[:title]).to eq('Not authenticated')
      expect(doc[:detail]).to eq(ErrorRendering::NOT_AUTHENTICATED_DETAIL)
      expect(doc[:how_to_authenticate]).to eq(ErrorRendering::HOW_TO_AUTHENTICATE)
    end

    it 'falls back to not-authenticated for a nil / unknown cause' do
      expect(SessionAwareFailureApp.problem_for(nil)[:type]).to eq('/api/docs/errors#not_authenticated')
      expect(SessionAwareFailureApp.problem_for(:some_future_symbol)[:type]).to eq('/api/docs/errors#not_authenticated')
    end
  end

  describe 'through real warden (unauthenticated request to an authenticated endpoint)' do
    it 'answers JSON requests with the problem envelope' do
      get '/projects', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/api/docs/errors#not_authenticated')
      expect(body['title']).to eq('Not authenticated')
      expect(body['how_to_authenticate']).to include('session', 'token')
    end

    it 'keeps HTML requests redirecting to sign in with a flash (unchanged)' do
      get '/projects', headers: { 'Accept' => 'text/html' }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(I18n.t('devise.failure.unauthenticated'))
    end
  end

  # End-to-end proof that the patched session-traceable hook (throws
  # :session_limited when a session is superseded) and this failure app wire
  # together: a real second login evicts the first session, and the evicted
  # session is told the true cause.
  describe 'real session eviction (max_active_sessions: 1)' do
    let(:password) { 'S3cure!#Pass001' }
    let(:user) { create(:user, password: password, password_confirmation: password) }

    def login(as_agent: 'RSpec Test Browser')
      post user_session_path,
           params: { user: { email: user.email, password: password } },
           headers: { 'User-Agent' => as_agent }
      expect(response).to redirect_to(root_path)
      response.headers['Set-Cookie']
    end

    def restore_cookies(cookie_header)
      return unless cookie_header

      cookie_header.split("\n").each do |line|
        name, value = line.split(';').first.split('=', 2)
        cookies[name.strip] = value&.strip
      end
    end

    it 'tells the evicted HTML session it was signed in elsewhere (session_limited flash)' do
      first_cookies = login
      reset!
      login # second login evicts the first
      reset!
      restore_cookies(first_cookies)

      get '/projects', headers: { 'Accept' => 'text/html' }

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq(I18n.t('devise.failure.session_limited'))
    end

    it 'answers the evicted JSON session with the session_superseded problem body' do
      first_cookies = login
      reset!
      login # second login evicts the first
      reset!
      restore_cookies(first_cookies)

      get '/projects', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/api/docs/errors#session_superseded')
      expect(body['title']).to eq('Session ended — signed in elsewhere')
      expect(body['detail']).to eq(
        'You were signed out because this account signed in from another location. ' \
        'Only one active session per account is allowed at a time.'
      )
      expect(body['how_to_authenticate']).to include('session', 'token')
    end
  end
end
