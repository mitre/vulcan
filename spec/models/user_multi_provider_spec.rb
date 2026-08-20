# frozen_string_literal: true

require 'rails_helper'

# Multi-provider OIDC: each registered OpenID Connect strategy reports its own
# name as auth.provider (e.g. :okta, :login_gov — the registry key, pinned via
# name: in the omniauth args). from_omniauth must record that exact name on
# users.provider so re-authentication and identity lookups are per-provider, not
# collapsed onto a single "oidc" value.
RSpec.describe User do
  describe '.from_omniauth records the per-provider strategy name' do
    def auth_for(provider, email:, uid:)
      OmniAuth::AuthHash.new(
        provider: provider,
        uid: uid,
        info: { email: email, name: 'Multi Provider User' },
        credentials: { id_token: 'fake-id-token' }
      )
    end

    it 'stores okta for a user who signs in through the okta strategy' do
      user = described_class.from_omniauth(auth_for(:okta, email: 'okta-person@example.com', uid: 'okta-1'))
      expect(user.provider).to eq('okta')
      expect(user.uid).to eq('okta-1')
    end

    it 'stores login_gov for a user who signs in through the login.gov strategy' do
      user = described_class.from_omniauth(auth_for(:login_gov, email: 'lg-person@example.com', uid: 'lg-1'))
      expect(user.provider).to eq('login_gov')
      expect(user.uid).to eq('lg-1')
    end

    it 'keeps two people on distinct providers as separate accounts' do
      okta = described_class.from_omniauth(auth_for(:okta, email: 'a@example.com', uid: 'okta-a'))
      login_gov = described_class.from_omniauth(auth_for(:login_gov, email: 'b@example.com', uid: 'lg-b'))

      expect([okta.provider, login_gov.provider]).to eq(%w[okta login_gov])
      expect(okta.id).not_to eq(login_gov.id)
    end
  end
end
