# frozen_string_literal: true

# Regression test: Secure cookie flag must NOT be set explicitly in session_store.rb
# or devise.rb. Rails' ActionDispatch::SSL middleware handles this automatically
# when config.force_ssl = true (production.rb).
#
# Setting `secure: true` explicitly breaks test/development (HTTP-only) and causes
# redirect loops in production when RAILS_FORCE_SSL=false (Docker quickstart).
#
# The correct pattern (used by Mastodon, Discourse):
# - session_store.rb: no `secure:` key
# - devise.rb rememberable_options: no `secure:` key
# - production.rb: config.force_ssl = ENV.fetch('RAILS_FORCE_SSL', 'true') != 'false'
# - ActionDispatch::SSL adds `; secure` to ALL cookies when force_ssl is active
#
# See: config/initializers/session_store.rb for full explanation.

require 'rails_helper'

RSpec.describe 'Secure cookie configuration' do
  before do
    Rails.application.reload_routes!
  end

  describe 'session store' do
    it 'does not explicitly set the secure flag (Rails handles this via force_ssl)' do
      session_options = Rails.application.config.session_options
      # The session store should NOT have an explicit :secure key.
      # If someone adds `secure: true` to session_store.rb, this test fails,
      # reminding them that ActionDispatch::SSL handles it automatically.
      expect(session_options).not_to have_key(:secure),
                                     'session_store.rb must NOT set `secure:` explicitly. ' \
                                     'ActionDispatch::SSL handles secure cookies when config.force_ssl = true. ' \
                                     'Setting it explicitly breaks test/dev sessions and causes redirect loops.'
    end
  end

  describe 'devise rememberable cookie' do
    it 'does not explicitly set the secure flag (Rails handles this via force_ssl)' do
      rememberable_options = Devise.rememberable_options
      expect(rememberable_options).not_to have_key(:secure),
                                          'devise.rb rememberable_options must NOT set `secure:` explicitly. ' \
                                          'ActionDispatch::SSL handles secure cookies when config.force_ssl = true.'
    end
  end

  describe 'session works over HTTP in test environment' do
    let(:user) { create(:user) }

    it 'maintains session across requests (proves cookies are not secure-only)' do
      sign_in user
      get root_path
      expect(response).not_to redirect_to(new_user_session_path),
                              'Signed-in user was redirected to login. This usually means the session cookie ' \
                              'has the secure flag set but tests run over HTTP, so the cookie is not sent back.'
    end
  end
end
