# frozen_string_literal: true

require 'rails_helper'

##
# Unlink external identity from user account
#
# REQUIREMENTS:
# A user whose local account was auto-linked to an external provider (OIDC/LDAP/GitHub)
# can unlink that identity and revert to a local-only account.
#
# SECURITY GUARDS:
# 1. Must be the owner (cannot unlink another user's identity)
# 2. Must provide valid current password — proves they can still authenticate locally
#    after the unlink (prevents lockout and proves account ownership)
# 3. Must not unlink if local login is disabled globally (would lock them out)
# 4. Must set BOTH provider AND uid to nil atomically (partial unique index)
# 5. Must audit the unlink event
RSpec.describe 'Users::RegistrationsController#unlink_identity' do
  let(:password) { 'S3cure!#TestPas1' }
  let(:user) do
    create(:user,
           email: 'linked@example.com',
           password: password,
           password_confirmation: password,
           provider: 'oidc',
           uid: 'okta-123')
  end

  before do
    Rails.application.reload_routes!
    sign_in user
  end

  describe 'POST /users/unlink_identity' do
    context 'with valid current password' do
      it 'clears provider and uid' do
        post '/users/unlink_identity', params: { current_password: password }

        user.reload
        expect(user.provider).to be_nil
        expect(user.uid).to be_nil
      end

      it 'returns success' do
        post '/users/unlink_identity', params: { current_password: password }
        expect(response).to have_http_status(:ok).or have_http_status(:found)
      end

      it 'creates an audit record for the unlink' do
        expect do
          post '/users/unlink_identity', params: { current_password: password }
        end.to change { user.audits.count }.by_at_least(1)
      end
    end

    context 'with invalid current password' do
      it 'does not clear provider or uid' do
        post '/users/unlink_identity', params: { current_password: 'wrong-password' }

        user.reload
        expect(user.provider).to eq('oidc')
        expect(user.uid).to eq('okta-123')
      end

      it 'sets a specific flash.alert explaining the wrong password' do
        post '/users/unlink_identity', params: { current_password: 'wrong-password' }
        expect(flash.alert).to match(/incorrect password/i)
      end

      it 'returns 422 for JSON requests' do
        post '/users/unlink_identity',
             params: { current_password: 'wrong-password' },
             headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when local login is disabled globally' do
      before do
        allow(Settings.local_login).to receive(:enabled).and_return(false)
      end

      it 'refuses to unlink (would lock user out)' do
        post '/users/unlink_identity', params: { current_password: password }

        user.reload
        expect(user.provider).to eq('oidc')
        expect(user.uid).to eq('okta-123')
      end

      it 'explains clearly why unlink is refused' do
        post '/users/unlink_identity', params: { current_password: password }
        expect(flash.alert).to match(/local login is disabled/i)
        expect(flash.alert).to match(/lock you out/i)
      end
    end

    context 'when account has no linked identity' do
      let!(:local_only_user) do
        create(:user, email: 'localonly@example.com',
                      password: password, password_confirmation: password,
                      provider: nil, uid: nil)
      end

      before do
        sign_out user
        sign_in local_only_user
      end

      it 'returns a clear error explaining there is nothing to unlink' do
        post '/users/unlink_identity', params: { current_password: password }
        expect(flash.alert).to match(/nothing to unlink/i)
      end
    end

    context 'when user has no local password yet' do
      # OmniAuth-created users get a random Devise.friendly_token they don't know.
      # We block unlink for those users with a clear message to set a password first.
      let(:omniauth_only_user) do
        # Create a user with OIDC provider, then nil out their known password.
        # In practice, OmniAuth users have a random token they cannot provide.
        u = create(:user, email: 'oidc-only@example.com',
                          password: password, password_confirmation: password,
                          provider: 'oidc', uid: 'okta-999')
        # Simulate an OmniAuth-only user by forcing a new random password they don't know
        u.update_columns(encrypted_password: Devise::Encryptor.digest(User, SecureRandom.hex(20)))
        u
      end

      before do
        sign_out user
        sign_in omniauth_only_user
      end

      it 'refuses to unlink when the provided password does not match' do
        post '/users/unlink_identity', params: { current_password: password }

        omniauth_only_user.reload
        expect(omniauth_only_user.provider).to eq('oidc')
      end
    end
  end
end
