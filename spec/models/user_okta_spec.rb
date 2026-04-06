# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  include LoginHelpers

  describe '.from_omniauth with OIDC/OKTA' do
    # IMPORTANT: Use symbol :oidc for provider in auth hashes to match real-world
    # OmniAuth behavior. When configured with `name: :oidc` in vulcan.default.yml,
    # OmniAuth's Strategy#name returns the symbol as-is (no .to_s conversion).
    # The DB stores provider as a string "oidc". Tests must verify that the
    # symbol/string comparison is handled correctly.

    let(:oidc_auth) do
      lambda { |email:, uid:, name: 'Test User', email_verified: nil|
        info = { email: email, name: name }
        info[:email_verified] = email_verified unless email_verified.nil?
        OmniAuth::AuthHash.new({
                                 provider: :oidc, # Symbol — matches real OmniAuth behavior
                                 uid: uid,
                                 info: info,
                                 credentials: { id_token: 'fake-id-token' }
                               })
      }
    end

    context 'when a new user logs in with OIDC' do
      it 'creates a new user with provider and uid' do
        auth = oidc_auth.call(email: 'newuser@example.com', uid: 'okta-new-123')

        expect { described_class.from_omniauth(auth) }.to change(described_class, :count).by(1)

        user = described_class.find_by(email: 'newuser@example.com')
        expect(user.provider).to eq('oidc')
        expect(user.uid).to eq('okta-new-123')
        expect(user.name).to eq('Test User')
      end
    end

    context 'when an existing OIDC user logs in again' do
      let!(:okta_user) { create(:user, email: 'okta@example.com', provider: 'oidc', uid: 'okta-uid-12345') }

      it 'finds the user by provider+uid without creating duplicates' do
        auth = oidc_auth.call(email: okta_user.email, uid: 'okta-uid-12345')

        expect { described_class.from_omniauth(auth) }.not_to change(described_class, :count)

        user = described_class.from_omniauth(auth)
        expect(user.id).to eq(okta_user.id)
      end

      it 'handles symbol provider from OmniAuth matching string provider in DB' do
        # Critical test: auth.provider is :oidc (symbol), user.provider is "oidc" (string).
        # Must not raise ProviderConflictError.
        auth = oidc_auth.call(email: okta_user.email, uid: 'okta-uid-12345')

        expect(auth.provider).to be_a(Symbol)
        expect(okta_user.provider).to be_a(String)

        expect { described_class.from_omniauth(auth) }.not_to raise_error
      end

      it 'does not create an audit record on re-authentication (nothing changed)' do
        # Re-authentication via provider+uid match should be a no-op on the user row.
        # Calling save! without changes creates audit noise and wastes DB writes.
        okta_user # ensure created
        initial_audit_count = okta_user.audits.count

        auth = oidc_auth.call(email: okta_user.email, uid: 'okta-uid-12345')
        described_class.from_omniauth(auth)

        expect(okta_user.audits.count).to eq(initial_audit_count)
      end
    end

    context 'when a local user tries to log in with OIDC' do
      let!(:local_user) { create(:user, email: 'local@example.com', provider: nil, uid: nil) }

      context 'when auto_link_user is disabled (default)' do # rubocop:disable RSpec/NestedGroups
        before do
          allow(Settings).to receive(:auto_link_user).and_return(false)
        end

        it 'raises ProviderConflictError with actionable message' do
          auth = oidc_auth.call(email: local_user.email, uid: 'okta-uid-999')

          expect { described_class.from_omniauth(auth) }.to raise_error(
            User::ProviderConflictError,
            /already exists using email and password sign-in/
          )

          local_user.reload
          expect(local_user.provider).to be_nil
          expect(local_user.uid).to be_nil
        end
      end

      context 'when auto_link_user is enabled' do # rubocop:disable RSpec/NestedGroups
        before do
          allow(Settings).to receive(:auto_link_user).and_return(true)
        end

        it 'links the OIDC provider to the existing local account' do
          auth = oidc_auth.call(email: local_user.email, uid: 'okta-uid-999', name: local_user.name)

          user = described_class.from_omniauth(auth)

          expect(user.id).to eq(local_user.id)
          expect(user.provider).to eq('oidc')
          expect(user.uid).to eq('okta-uid-999')
        end

        it 'flags the returned user with just_auto_linked? so callers can show UX feedback' do
          auth = oidc_auth.call(email: local_user.email, uid: 'okta-uid-999')

          user = described_class.from_omniauth(auth)

          expect(user.just_auto_linked?).to be true
        end

        it 'does not create a duplicate user' do
          auth = oidc_auth.call(email: local_user.email, uid: 'okta-uid-999')

          expect { described_class.from_omniauth(auth) }.not_to change(described_class, :count)
        end

        it 'links when provider asserts email_verified=true' do
          auth = oidc_auth.call(email: local_user.email, uid: 'okta-uid-999', email_verified: true)

          user = described_class.from_omniauth(auth)

          expect(user.id).to eq(local_user.id)
          expect(user.provider).to eq('oidc')
        end

        it 'links when provider does not set email_verified claim (backward compat)' do
          # Many providers (Okta default, GitHub) do not include email_verified in the info hash.
          # Auto-link is gated on auto_link_user=true which implies admin trusts the provider.
          auth = oidc_auth.call(email: local_user.email, uid: 'okta-uid-999')

          expect(auth.info.respond_to?(:email_verified) && auth.info.email_verified).to be_falsey
          expect { described_class.from_omniauth(auth) }.not_to raise_error
          expect(local_user.reload.provider).to eq('oidc')
        end

        it 'SECURITY: refuses to link when provider explicitly asserts email_verified=false' do
          auth = oidc_auth.call(email: local_user.email, uid: 'okta-uid-999', email_verified: false)

          expect { described_class.from_omniauth(auth) }.to raise_error(
            User::ProviderConflictError, /email.*not verified/i
          )
          expect(local_user.reload.provider).to be_nil
        end
      end
    end

    context 'when a user with a different non-local provider tries OIDC' do
      let!(:github_user) { create(:user, email: 'ghuser@example.com', provider: 'github', uid: 'gh-123') }

      before do
        allow(Settings).to receive(:auto_link_user).and_return(true)
      end

      it 'raises ProviderConflictError even with auto_link enabled' do
        # Auto-link only applies to local (nil provider) accounts
        auth = oidc_auth.call(email: github_user.email, uid: 'okta-uid-111')

        expect { described_class.from_omniauth(auth) }.to raise_error(
          User::ProviderConflictError,
          /already exists using GITHUB sign-in/
        )
      end
    end

    context 'when provider+uid matches but email changed at OIDC provider' do
      let!(:okta_user) { create(:user, email: 'old@example.com', provider: 'oidc', uid: 'okta-uid-12345') }

      it 'finds by provider+uid regardless of email change' do
        auth = oidc_auth.call(email: 'new@example.com', uid: 'okta-uid-12345')

        user = described_class.from_omniauth(auth)

        expect(user.id).to eq(okta_user.id)
      end
    end

    context 'when provider matches but uid changed (re-issued)' do
      let!(:okta_user) { create(:user, email: 'okta@example.com', provider: 'oidc', uid: 'old-uid') }

      it 'updates the uid via email fallback' do
        auth = oidc_auth.call(email: okta_user.email, uid: 'new-uid')

        user = described_class.from_omniauth(auth)

        expect(user.id).to eq(okta_user.id)
        expect(user.reload.uid).to eq('new-uid')
      end
    end

    describe 'just_auto_linked? flag on non-linking paths' do
      it 'is false for new user creation' do
        auth = oidc_auth.call(email: 'brandnew@example.com', uid: 'okta-new-1')
        user = described_class.from_omniauth(auth)
        expect(user.just_auto_linked?).to be false
      end

      it 'is false for re-authentication of existing OIDC user' do
        create(:user, email: 'existing@example.com', provider: 'oidc', uid: 'okta-existing')
        auth = oidc_auth.call(email: 'existing@example.com', uid: 'okta-existing')
        user = described_class.from_omniauth(auth)
        expect(user.just_auto_linked?).to be false
      end
    end

    describe 'UX error message regression' do
      before do
        allow(Settings).to receive(:auto_link_user).and_return(false)
      end

      it 'says "email and password" not "local" for local accounts' do
        create(:user, email: 'localuser@example.com', provider: nil, uid: nil)
        auth = oidc_auth.call(email: 'localuser@example.com', uid: 'okta-999')

        expect { described_class.from_omniauth(auth) }.to raise_error(
          User::ProviderConflictError, /email and password sign-in/
        )
      end

      it 'uppercases provider name for non-local accounts' do
        create(:user, email: 'ldapuser@example.com', provider: 'ldap', uid: 'ldap-999')
        auth = oidc_auth.call(email: 'ldapuser@example.com', uid: 'okta-888')

        expect { described_class.from_omniauth(auth) }.to raise_error(
          User::ProviderConflictError, /LDAP sign-in/
        )
      end

      it 'does not expose the user email in the error message' do
        create(:user, email: 'secret@example.com', provider: nil, uid: nil)
        auth = oidc_auth.call(email: 'secret@example.com', uid: 'okta-777')

        expect { described_class.from_omniauth(auth) }.to raise_error(User::ProviderConflictError) do |error|
          expect(error.message).not_to include('secret@example.com')
        end
      end
    end
  end
end
