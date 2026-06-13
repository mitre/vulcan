# frozen_string_literal: true

require 'rails_helper'

# ADR docs/decisions/adr-multi-provider-oidc.md §1 (config shape) + §7 (legacy
# backward-compat). Settings.oidc.providers is the single surface the rest of
# the epic reads: a list of provider configs, one per VULCAN_OIDC_PROVIDERS
# registry key, OR a single provider named `oidc` from the unprefixed legacy
# vars when the registry is unset.
RSpec.describe 'OIDC provider registry (Settings.oidc.providers)' do
  # Helper: a provider entry by name, regardless of whether providers is an
  # array of hashes or settingslogic sub-objects.
  def provider(name)
    Array(Settings.oidc.providers).map { |p| p.respond_to?(:to_h) ? p.to_h.symbolize_keys : p }
                                  .find { |p| p[:name].to_s == name.to_s }
  end

  after { Settings.reload! } # restore global Settings from the real ENV

  describe 'registry mode — VULCAN_OIDC_PROVIDERS=okta,login_gov' do
    around do |example|
      ClimateControl.modify(
        VULCAN_ENABLE_OIDC: 'true',
        VULCAN_OIDC_PROVIDERS: 'okta,login_gov',
        VULCAN_OIDC_OKTA_ISSUER_URL: 'https://org.okta.com/oauth2/default',
        VULCAN_OIDC_OKTA_CLIENT_ID: 'okta-client',
        VULCAN_OIDC_OKTA_CLIENT_SECRET: 'okta-secret',
        VULCAN_OIDC_OKTA_TITLE: 'Okta',
        VULCAN_OIDC_LOGIN_GOV_ISSUER_URL: 'https://idp.int.identitysandbox.gov',
        VULCAN_OIDC_LOGIN_GOV_CLIENT_ID: 'urn:gov:gsa:openidconnect:vulcan',
        VULCAN_OIDC_LOGIN_GOV_CLIENT_AUTH_METHOD: 'jwt_bearer',
        VULCAN_OIDC_LOGIN_GOV_TITLE: 'login.gov'
      ) { Settings.reload! && example.run }
    end

    it 'returns exactly two providers with the registry keys as names' do
      names = Array(Settings.oidc.providers).map { |p| (p.respond_to?(:name) ? p.name : p[:name]).to_s }
      expect(names).to eq(%w[okta login_gov])
    end

    it 'carries per-provider issuer, client_id, and title' do
      expect(provider('okta')).to include(
        issuer: 'https://org.okta.com/oauth2/default',
        title: 'Okta'
      )
      expect(provider('okta')[:client_id].to_s).to eq('okta-client')
      expect(provider('login_gov')).to include(
        issuer: 'https://idp.int.identitysandbox.gov',
        title: 'login.gov'
      )
    end

    it 'defaults client_auth_method to secret and honors jwt_bearer per provider' do
      expect(provider('okta')[:client_auth_method].to_s).to eq('secret')
      expect(provider('login_gov')[:client_auth_method].to_s).to eq('jwt_bearer')
    end
  end

  describe 'legacy mode — VULCAN_OIDC_PROVIDERS unset, VULCAN_ENABLE_OIDC=true' do
    around do |example|
      ClimateControl.modify(
        VULCAN_ENABLE_OIDC: 'true',
        VULCAN_OIDC_PROVIDERS: nil,
        VULCAN_OIDC_ISSUER_URL: 'https://legacy.example.com',
        VULCAN_OIDC_CLIENT_ID: 'legacy-client',
        VULCAN_OIDC_PROVIDER_TITLE: 'Legacy SSO'
      ) { Settings.reload! && example.run }
    end

    it 'yields exactly one provider named oidc built from the unprefixed vars' do
      names = Array(Settings.oidc.providers).map { |p| (p.respond_to?(:name) ? p.name : p[:name]).to_s }
      expect(names).to eq(%w[oidc])
      expect(provider('oidc')).to include(issuer: 'https://legacy.example.com', title: 'Legacy SSO')
      expect(provider('oidc')[:client_id].to_s).to eq('legacy-client')
    end
  end
end
