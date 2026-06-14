# frozen_string_literal: true

require 'rails_helper'

# User identity mutation API — the SINGLE source of truth for all identity
# state changes. Every controller and from_omniauth delegates to these methods.
RSpec.describe User do
  def auth_hash(provider:, uid:, email:)
    OmniAuth::AuthHash.new(
      provider: provider, uid: uid,
      info: { email: email, name: 'Test' },
      credentials: {}, extra: { raw_info: {} }
    )
  end

  describe '#link_identity!' do
    let(:user) { create(:user, provider: nil, uid: nil) }

    it 'creates an Identity, syncs denorm, and returns the identity' do
      identity = user.link_identity!(provider: 'okta', uid: 'okta-1', email: 'u@example.com')

      expect(identity).to be_a(Identity)
      expect(identity).to be_persisted
      expect(identity.provider).to eq('okta')
      expect(identity.uid).to eq('okta-1')
      expect(identity.email).to eq('u@example.com')
      expect(identity.last_sign_in_at).to be_within(5.seconds).of(Time.current)
      expect(user.reload.provider).to eq('okta')
      expect(user.uid).to eq('okta-1')
    end

    it 'updates an existing identity for the same provider (uid reissue)' do
      user.link_identity!(provider: 'okta', uid: 'old-uid', email: 'u@example.com')
      expect { user.link_identity!(provider: 'okta', uid: 'new-uid', email: 'u@example.com') }
        .not_to change(Identity, :count)

      expect(Identity.find_by(provider: 'okta', user: user).uid).to eq('new-uid')
    end

    it 'allows linking multiple providers (multi-link)' do
      user.link_identity!(provider: 'okta', uid: 'okta-1', email: 'u@example.com')
      user.link_identity!(provider: 'login_gov', uid: 'lg-1', email: 'u@example.com')

      expect(user.identities.count).to eq(2)
      expect(user.identities.pluck(:provider)).to contain_exactly('okta', 'login_gov')
    end

    it 'raises ProviderConflictError when (provider, uid) belongs to another user' do
      other = create(:user, email: 'other@example.com')
      create(:identity, user: other, provider: 'okta', uid: 'taken-uid')

      expect { user.link_identity!(provider: 'okta', uid: 'taken-uid', email: 'u@example.com') }
        .to raise_error(User::ProviderConflictError, /already linked to another account/)
    end
  end

  describe '#unlink_identity!' do
    let(:user) { create(:user, provider: 'okta', uid: 'okta-1', password: 'S3cure!#TestPas1', password_confirmation: 'S3cure!#TestPas1') }
    let!(:identity) { create(:identity, user: user, provider: 'okta', uid: 'okta-1') }

    it 'destroys the identity and syncs denorm to nil when no identities remain' do
      user.unlink_identity!(identity)

      expect(Identity.where(id: identity.id)).not_to exist
      expect(user.reload.provider).to be_nil
      expect(user.uid).to be_nil
    end

    it 'syncs denorm to the next remaining identity after unlink' do
      create(:identity, user: user, provider: 'login_gov', uid: 'lg-1',
                        last_sign_in_at: 1.hour.ago)
      user.unlink_identity!(identity)

      expect(user.reload.provider).to eq('login_gov')
      expect(user.uid).to eq('lg-1')
    end

    it 'raises when can_unlink? is false (last sign-in method, no password)' do
      user.update_columns(encrypted_password: '')
      expect { user.unlink_identity!(identity) }
        .to raise_error(User::IdentityGuardError, /last sign-in method/)
    end
  end

  describe '#can_unlink?' do
    let(:user) { create(:user, provider: 'okta', uid: 'okta-1', password: 'S3cure!#TestPas1', password_confirmation: 'S3cure!#TestPas1') }
    let!(:identity) { create(:identity, user: user, provider: 'okta', uid: 'okta-1') }

    it 'returns true when user has a password (even if this is the only identity)' do
      expect(user.can_unlink?(identity)).to be(true)
    end

    it 'returns true when user has another identity (even without a password)' do
      user.update_columns(encrypted_password: '')
      create(:identity, user: user, provider: 'login_gov', uid: 'lg-1')

      expect(user.can_unlink?(identity)).to be(true)
    end

    it 'returns false when this is the only identity AND no password' do
      user.update_columns(encrypted_password: '')
      expect(user.can_unlink?(identity)).to be(false)
    end
  end
end
