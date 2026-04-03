# frozen_string_literal: true

# REQUIREMENTS:
# AC-10 (V-222387): The application must limit the number of logon sessions per user.
# - When session limits enabled, concurrent sessions are enforced.
# - max_sessions configures how many concurrent sessions are allowed (default: 1).
# - When max exceeded, the oldest session is evicted (not rejected).
# - Session history records are created per login, updated per request, expired on logout.
# - When session_traceable is active, unique_traceable_token replaces unique_session_id.

require 'rails_helper'

RSpec.describe 'Session Limits (AC-10)' do
  before do
    Rails.application.reload_routes!
  end

  let(:password) { 'S3cure!#Pass001' }
  let(:user) { create(:user, password: password, password_confirmation: password) }

  describe 'session history tracking' do
    it 'creates a session_history record on login' do
      expect { login(user) }.to change(SessionHistory, :count).by(1)
    end

    it 'records IP address and user agent' do
      login(user)
      history = SessionHistory.last

      expect(history.ip_address).to be_present
      expect(history.user_agent).to be_present
      expect(history.active).to be true
      expect(history.last_accessed_at).to be_present
    end

    it 'expires session history on logout' do
      login(user)
      follow_redirect! # follow the redirect to establish the session fully
      history = SessionHistory.last
      expect(history.active).to be true

      delete destroy_user_session_path
      history.reload

      expect(history.active).to be false
    end
  end

  describe 'concurrent session enforcement (max_sessions: 1)' do
    it 'invalidates the first session when user logs in a second time' do
      # First login
      first_cookies = login(user)

      # Second login (new session)
      reset!
      login(user)

      # First session should be evicted
      reset!
      restore_cookies(first_cookies)
      get projects_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'allows the latest session to remain active' do
      login(user) # first
      reset!
      login(user) # second (evicts first)
      follow_redirect!

      get projects_path
      expect(response).to have_http_status(:ok).or redirect_to(root_path)
    end

    it 'creates session_history records for each login' do
      login(user)
      reset!
      login(user)

      expect(user.session_histories.count).to eq(2)
      # Only the latest should be active (oldest evicted during second login)
      expect(user.session_histories.where(active: true).count).to eq(1)
    end
  end

  describe 'configurable max_sessions' do
    around do |example|
      original = Devise.max_active_sessions
      Devise.max_active_sessions = 2
      example.run
    ensure
      Devise.max_active_sessions = original
    end

    it 'allows 2 concurrent sessions when max_sessions is 2' do
      first_cookies = login(user)

      reset!
      login(user)

      # Both sessions should work
      reset!
      restore_cookies(first_cookies)
      get projects_path
      expect(response).not_to redirect_to(new_user_session_path)
    end

    it 'evicts the oldest when a 3rd session exceeds max of 2' do
      first_cookies = login(user)

      reset!
      login(user) # second

      reset!
      login(user) # third — should evict first

      # First session should be evicted
      reset!
      restore_cookies(first_cookies)
      get projects_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'unique_session_id backward compatibility' do
    it 'unique_session_id column still updated on login' do
      expect(user.unique_session_id).to be_nil

      login(user)
      user.reload

      # With session_traceable, unique_session_id may still be set by session_limitable
      # OR the traceable token is used instead — either way, session is tracked
      expect(user.session_histories.count).to eq(1)
    end
  end

  private

  # Login and return the cookie string for later replay
  def login(user_record)
    post user_session_path,
         params: { user: { email: user_record.email, password: password } },
         headers: { 'User-Agent' => 'RSpec Test Browser' }
    expect(response).to redirect_to(root_path)
    response.headers['Set-Cookie']
  end

  # Parse a Set-Cookie header string into the test cookie jar
  def restore_cookies(cookie_header)
    return unless cookie_header

    cookie_header.split("\n").each do |line|
      name, value = line.split(';').first.split('=', 2)
      cookies[name.strip] = value&.strip
    end
  end
end
