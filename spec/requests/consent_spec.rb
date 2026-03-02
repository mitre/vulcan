# frozen_string_literal: true

require 'rails_helper'

# Requirements (NIST AC-8):
# - Display notification BEFORE granting access (consent blocks login page)
# - Retain notification until user acknowledges and takes explicit action to log on
# - Acknowledgment tied to authentication session, not browser lifecycle
# - Server-side tracking provides audit trail and prevents tampering
# - Optional TTL allows configurable consent duration within a session
#
# Flow: login page → consent modal blocks → user clicks "I Agree" →
# consent stored in session → user logs in → consent preserved across
# Devise session reset → user accesses app without seeing modal again.

RSpec.describe 'Consent Acknowledgment (AC-8)' do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  before do
    Rails.application.reload_routes!
  end

  def consent_config_from_response
    match = response.body.match(/consent_config='([^']+)'/)
    return {} unless match

    JSON.parse(CGI.unescapeHTML(match[1]))
  end

  describe 'POST /consent/acknowledge' do
    it 'works without authentication (consent happens before login)' do
      post '/consent/acknowledge'
      expect(response).to have_http_status(:ok)
    end

    it 'stores acknowledgment in session' do
      post '/consent/acknowledge'
      # Verify by checking consent_required on next request
      Settings.consent['enabled'] = true
      Settings.consent['title'] = 'Terms'
      Settings.consent['content'] = 'Agree.'

      get new_user_session_path
      expect(consent_config_from_response['required']).to be false

      Settings.consent['enabled'] = false
    end
  end

  describe 'consent on login page (AC-8: before granting access)' do
    before do
      Settings.consent['enabled'] = true
      Settings.consent['title'] = 'Terms'
      Settings.consent['content'] = 'Agree.'
    end

    after do
      Settings.consent['enabled'] = false
    end

    it 'requires consent on login page (blocks access before authentication)' do
      get new_user_session_path
      expect(consent_config_from_response['required']).to be true
    end

    it 'does not require consent after acknowledgment on login page' do
      post '/consent/acknowledge'
      get new_user_session_path
      expect(consent_config_from_response['required']).to be false
    end
  end

  describe 'consent preserved across login (session reset)' do
    before do
      Settings.consent['enabled'] = true
      Settings.consent['title'] = 'Terms'
      Settings.consent['content'] = 'Agree.'
    end

    after do
      Settings.consent['enabled'] = false
    end

    it 'preserves consent acknowledgment after Devise login' do
      # Acknowledge on login page (before auth)
      post '/consent/acknowledge'

      # Log in (Devise resets session, but consent is preserved)
      sign_in user

      # After login, consent should still be acknowledged
      get root_path
      expect(consent_config_from_response['required']).to be false
    end
  end

  describe 'consent_required? when disabled' do
    before do
      Settings.consent['enabled'] = false
    end

    it 'sets required to false' do
      get new_user_session_path
      expect(consent_config_from_response['required']).to be false
    end
  end

  describe 'consent_required? when signed in and not acknowledged' do
    before do
      sign_in user
      Settings.consent['enabled'] = true
      Settings.consent['title'] = 'Terms'
      Settings.consent['content'] = 'Agree to terms.'
    end

    after do
      Settings.consent['enabled'] = false
    end

    it 'sets required to true' do
      get root_path
      expect(consent_config_from_response['required']).to be true
    end
  end

  describe 'consent_required? when signed in and acknowledged' do
    before do
      sign_in user
      Settings.consent['enabled'] = true
      Settings.consent['title'] = 'Terms'
      Settings.consent['content'] = 'Agree to terms.'
    end

    after do
      Settings.consent['enabled'] = false
    end

    it 'sets required to false after acknowledgment' do
      post '/consent/acknowledge'
      get root_path
      expect(consent_config_from_response['required']).to be false
    end
  end

  describe 'consent_required? with TTL configured' do
    before do
      sign_in user
      Settings.consent['enabled'] = true
      Settings.consent['ttl'] = '1h'
      Settings.consent['title'] = 'Terms'
      Settings.consent['content'] = 'Agree to terms.'
    end

    after do
      Settings.consent['enabled'] = false
      Settings.consent['ttl'] = '0'
    end

    it 'sets required to false within TTL window' do
      post '/consent/acknowledge'
      get root_path
      expect(consent_config_from_response['required']).to be false
    end

    it 'sets required to true after TTL expires' do
      Settings.consent['ttl'] = '1m'

      post '/consent/acknowledge'

      travel_to(2.minutes.from_now) do
        get root_path
        expect(consent_config_from_response['required']).to be true
      end
    end
  end

  describe 'consent_required? with TTL 0 (per-session default)' do
    before do
      sign_in user
      Settings.consent['enabled'] = true
      Settings.consent['ttl'] = '0'
      Settings.consent['title'] = 'Terms'
      Settings.consent['content'] = 'Agree to terms.'
    end

    after do
      Settings.consent['enabled'] = false
    end

    it 'sets required to false after acknowledgment (valid for session lifetime)' do
      post '/consent/acknowledge'
      get root_path
      expect(consent_config_from_response['required']).to be false
    end
  end
end
