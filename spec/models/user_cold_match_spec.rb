# frozen_string_literal: true

require 'rails_helper'

# Cold-match block (ADR §6a): when a user signs in via an unlinked provider
# whose email matches an existing account, the error must give actionable
# guidance to sign in with the existing method and connect from settings —
# never a silent merge, never a dead-end "already exists" without next steps.
RSpec.describe User do
  def auth_for(provider, email:, uid:, email_verified: nil)
    info = { email: email, name: 'Cold Match User' }
    info[:email_verified] = email_verified unless email_verified.nil?
    OmniAuth::AuthHash.new(
      provider: provider, uid: uid, info: info,
      credentials: { id_token: 'fake' }, extra: { raw_info: {} }
    )
  end

  describe 'cold-match block with actionable guidance' do
    context 'when an SSO user tries a different SSO provider (auto_link irrelevant)' do
      let!(:okta_user) { create(:user, email: 'joe@example.com', provider: 'okta', uid: 'okta-joe') }

      it 'blocks with a message containing both the existing method and connect guidance' do
        auth = auth_for(:login_gov, email: 'joe@example.com', uid: 'lg-joe')

        expect { described_class.from_omniauth(auth) }
          .to raise_error(User::ProviderConflictError) { |e|
            expect(e.message).to include('OKTA')
            expect(e.message).to match(/sign in/i)
            expect(e.message).to match(/connect/i)
          }
      end
    end

    context 'when a local user tries SSO with auto_link OFF' do
      let!(:local_user) { create(:user, email: 'local@example.com', provider: nil, uid: nil) }

      before { allow(Settings).to receive(:auto_link_user).and_return(false) }

      it 'blocks with guidance to sign in with password and connect' do
        auth = auth_for(:okta, email: 'local@example.com', uid: 'okta-local')

        expect { described_class.from_omniauth(auth) }
          .to raise_error(User::ProviderConflictError) { |e|
            expect(e.message).to match(/email and password/i)
            expect(e.message).to match(/connect/i)
          }
      end
    end

    context 'when email_verified=false (existing guard)' do
      let!(:local_user) { create(:user, email: 'unverified@example.com', provider: nil, uid: nil) }

      before { allow(Settings).to receive(:auto_link_user).and_return(true) }

      it 'still refuses with the email-not-verified message (unchanged)' do
        auth = auth_for(:okta, email: 'unverified@example.com', uid: 'okta-unv', email_verified: false)

        expect { described_class.from_omniauth(auth) }
          .to raise_error(User::ProviderConflictError, /not verified/i)
      end
    end

    it 'does NOT leak internal details (no column values, no user IDs)' do
      create(:user, email: 'safe@example.com', provider: 'okta', uid: 'okta-safe')
      auth = auth_for(:login_gov, email: 'safe@example.com', uid: 'lg-safe')

      expect { described_class.from_omniauth(auth) }
        .to raise_error(User::ProviderConflictError) { |e|
          expect(e.message).not_to match(/id.*=.*\d+/i)
          expect(e.message).not_to include('okta-safe')
        }
    end
  end
end
