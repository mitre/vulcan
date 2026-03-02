# frozen_string_literal: true

require 'rails_helper'

# Requirements (NIST AC-8):
# - System must display notification BEFORE granting access
# - Notification must be retained until user acknowledges and takes explicit action to log on
# - Acknowledgment must be tied to the authentication session, not browser lifecycle
# - Server-side tracking provides audit trail and prevents client-side tampering
# - Optional TTL allows configurable consent duration within a session
#
# These tests verify the server-side consent tracking endpoint and helper.

RSpec.describe 'Consent Acknowledgment (AC-8)' do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  before do
    Rails.application.reload_routes!
  end

  # Helper to extract the consent_config JSON from the rendered HTML.
  # The layout renders it as an HTML-escaped JSON string in a v-bind attribute.
  def consent_config_from_response
    # Match the HTML-escaped JSON in v-bind:consent_config='...'
    match = response.body.match(/consent_config='([^']+)'/)
    return {} unless match

    # Unescape HTML entities and parse JSON
    json_str = CGI.unescapeHTML(match[1])
    JSON.parse(json_str)
  end

  describe 'POST /consent/acknowledge' do
    context 'when not authenticated' do
      it 'redirects to login' do
        post '/consent/acknowledge'
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated' do
      before { sign_in user }

      it 'returns 200 OK' do
        post '/consent/acknowledge'
        expect(response).to have_http_status(:ok)
      end

      it 'stores acknowledgment in session so consent is no longer required' do
        Settings.consent['enabled'] = true
        Settings.consent['title'] = 'Terms'
        Settings.consent['content'] = 'Agree.'

        # Before acknowledgment
        get root_path
        expect(consent_config_from_response['required']).to be true

        # Acknowledge
        post '/consent/acknowledge'

        # After acknowledgment
        get root_path
        expect(consent_config_from_response['required']).to be false

        Settings.consent['enabled'] = false
      end
    end
  end

  describe 'consent_required? helper' do
    before do
      sign_in user
    end

    context 'when consent is disabled' do
      before do
        Settings.consent['enabled'] = false
      end

      it 'sets required to false' do
        get root_path
        expect(consent_config_from_response['required']).to be false
      end
    end

    context 'when consent is enabled and not acknowledged' do
      before do
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

    context 'when consent is enabled and acknowledged' do
      before do
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

    context 'when consent TTL is configured' do
      before do
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
        # Use a short TTL (1 minute) and travel past it but within session timeout
        Settings.consent['ttl'] = '1m'

        post '/consent/acknowledge'

        travel_to(2.minutes.from_now) do
          get root_path
          expect(consent_config_from_response['required']).to be true
        end
      end
    end

    context 'when TTL is 0 (default, per-session)' do
      before do
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
end
