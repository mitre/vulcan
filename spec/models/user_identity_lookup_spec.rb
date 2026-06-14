# frozen_string_literal: true

require 'rails_helper'

# Identity-first from_omniauth: the primary lookup uses
# Identity.find_by(provider:, uid:), not User.find_by(provider:, uid:).
# Every successful auth creates or updates an Identity row alongside the
# denormalized users.provider/uid. The behavioral contract is unchanged —
# the 73 existing auth tests verify that; these tests verify the new
# identity-side effects.
RSpec.describe User do
  def auth_for(provider, email:, uid:, name: 'Test User', email_verified: nil)
    info = { email: email, name: name }
    info[:email_verified] = email_verified unless email_verified.nil?
    OmniAuth::AuthHash.new(
      provider: provider,
      uid: uid,
      info: info,
      credentials: { id_token: 'fake-id-token' },
      extra: { raw_info: {} }
    )
  end

  describe 'identity-first lookup (LOOKUP 1)' do
    let!(:user) { create(:user, provider: 'okta', uid: 'okta-existing') }
    let!(:identity) { create(:identity, user: user, provider: 'okta', uid: 'okta-existing', email: user.email) }

    it 'finds the user via Identity, not User.find_by(provider:, uid:)' do
      result = described_class.from_omniauth(auth_for(:okta, email: user.email, uid: 'okta-existing'))
      expect(result.id).to eq(user.id)
    end

    it 'updates the identity last_sign_in_at on re-auth' do
      expect { described_class.from_omniauth(auth_for(:okta, email: user.email, uid: 'okta-existing')) }
        .to change { identity.reload.last_sign_in_at }.from(nil)
    end

    it 'syncs the denormalized users.provider/uid to the matched identity' do
      described_class.from_omniauth(auth_for(:okta, email: user.email, uid: 'okta-existing'))
      user.reload
      expect(user.provider).to eq('okta')
      expect(user.uid).to eq('okta-existing')
    end
  end

  describe 'new user creation (LOOKUP 3)' do
    it 'creates both a User and an Identity in one transaction' do
      auth = auth_for(:login_gov, email: 'brand-new@example.com', uid: 'lg-new-1')

      expect { described_class.from_omniauth(auth) }
        .to change(described_class, :count).by(1)
        .and change(Identity, :count).by(1)

      user = described_class.find_by(email: 'brand-new@example.com')
      identity = Identity.find_by(provider: 'login_gov', uid: 'lg-new-1')
      expect(identity.user_id).to eq(user.id)
      expect(identity.email).to eq('brand-new@example.com')
      expect(identity.last_sign_in_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe 'auto-link local→SSO (LOOKUP 2b)' do
    let!(:local_user) { create(:user, email: 'local@example.com', provider: nil, uid: nil) }

    before { allow(Settings).to receive(:auto_link_user).and_return(true) }

    it 'creates an Identity for the linked provider' do
      auth = auth_for(:okta, email: 'local@example.com', uid: 'okta-link-1', email_verified: true)

      expect { described_class.from_omniauth(auth) }
        .to change(Identity, :count).by(1)

      identity = Identity.find_by(provider: 'okta', uid: 'okta-link-1')
      expect(identity.user_id).to eq(local_user.id)
      expect(identity.email).to eq('local@example.com')
    end

    it 'still syncs the denormalized users.provider/uid' do
      described_class.from_omniauth(auth_for(:okta, email: 'local@example.com', uid: 'okta-link-1', email_verified: true))
      local_user.reload
      expect(local_user.provider).to eq('okta')
      expect(local_user.uid).to eq('okta-link-1')
    end
  end

  describe 'same-provider uid reissue (LOOKUP 2a)' do
    let!(:user) { create(:user, provider: 'okta', uid: 'old-uid', email: 'reissue@example.com') }
    let!(:identity) { create(:identity, user: user, provider: 'okta', uid: 'old-uid', email: user.email) }

    it 'updates the existing identity uid instead of creating a duplicate' do
      auth = auth_for(:okta, email: 'reissue@example.com', uid: 'new-uid')

      expect { described_class.from_omniauth(auth) }
        .not_to change(Identity, :count)

      expect(identity.reload.uid).to eq('new-uid')
      expect(user.reload.uid).to eq('new-uid')
    end
  end
end
