# frozen_string_literal: true

require 'rails_helper'

# Direct unit tests for the OIDC registry builder (the tested-Ruby-builder half
# of ADR §1). Settings.oidc.providers integration is covered in
# spec/config/oidc_providers_spec.rb; here we drive the builder with explicit
# env hashes — no Settings reload — to pin field mapping, legacy vs registry
# shapes, validation, and defaults.
RSpec.describe OidcProviderRegistry do
  def build(env)
    described_class.from_env(env)
  end

  describe 'registry mode' do
    let(:env) do
      {
        'VULCAN_ENABLE_OIDC' => 'true',
        'VULCAN_OIDC_PROVIDERS' => 'okta,login_gov',
        'VULCAN_OIDC_OKTA_ISSUER_URL' => 'https://org.okta.com/oauth2/default',
        'VULCAN_OIDC_OKTA_CLIENT_ID' => 'okta-id',
        'VULCAN_OIDC_OKTA_CLIENT_SECRET' => 'okta-secret',
        'VULCAN_OIDC_OKTA_TITLE' => 'Okta',
        'VULCAN_OIDC_OKTA_REDIRECT_URI' => 'https://vulcan.example/users/auth/okta/callback',
        'VULCAN_OIDC_OKTA_TOKEN_URL' => 'https://org.okta.com/oauth2/v1/token',
        'VULCAN_OIDC_LOGIN_GOV_ISSUER_URL' => 'https://idp.int.identitysandbox.gov',
        'VULCAN_OIDC_LOGIN_GOV_CLIENT_ID' => 'urn:gov:gsa:openidconnect:vulcan',
        'VULCAN_OIDC_LOGIN_GOV_CLIENT_AUTH_METHOD' => 'jwt_bearer',
        'VULCAN_OIDC_LOGIN_GOV_PRIVATE_KEY_PATH' => '/secrets/login_gov.pem',
        'VULCAN_OIDC_LOGIN_GOV_ACR_VALUES' => 'urn:acr.login.gov:auth-only',
        'VULCAN_OIDC_LOGIN_GOV_TITLE' => 'login.gov'
      }
    end

    it 'builds one entry per registry key, in order' do
      expect(build(env).pluck('name')).to eq(%w[okta login_gov])
    end

    it 'maps the full okta field set including endpoint overrides' do
      okta = build(env).find { |p| p['name'] == 'okta' }
      expect(okta).to include(
        'name' => 'okta',
        'title' => 'Okta',
        'issuer' => 'https://org.okta.com/oauth2/default',
        'client_id' => 'okta-id',
        'client_secret' => 'okta-secret',
        'client_auth_method' => 'secret',
        'client_signing_alg' => 'RS256',
        'redirect_uri' => 'https://vulcan.example/users/auth/okta/callback',
        'token_endpoint' => 'https://org.okta.com/oauth2/v1/token',
        'discovery' => true,
        'port' => 443,
        'scheme' => 'https'
      )
    end

    it 'maps login.gov jwt_bearer + key path + acr_values' do
      lg = build(env).find { |p| p['name'] == 'login_gov' }
      expect(lg).to include(
        'client_auth_method' => 'jwt_bearer',
        'private_key_path' => '/secrets/login_gov.pem',
        'acr_values' => 'urn:acr.login.gov:auth-only',
        'title' => 'login.gov'
      )
    end

    it 'falls back the title to the key when no TITLE var is set' do
      env.delete('VULCAN_OIDC_OKTA_TITLE')
      expect(build(env).find { |p| p['name'] == 'okta' }['title']).to eq('okta')
    end
  end

  describe 'legacy mode (registry unset)' do
    let(:env) do
      {
        'VULCAN_ENABLE_OIDC' => 'true',
        'VULCAN_OIDC_ISSUER_URL' => 'https://legacy.example.com',
        'VULCAN_OIDC_CLIENT_ID' => 'legacy-id',
        'VULCAN_OIDC_CLIENT_SECRET' => 'legacy-secret',
        'VULCAN_OIDC_PROVIDER_TITLE' => 'Legacy SSO'
      }
    end

    it 'yields one provider named oidc from the unprefixed vars' do
      providers = build(env)
      expect(providers.size).to eq(1)
      expect(providers.first).to include(
        'name' => 'oidc',
        'title' => 'Legacy SSO',
        'issuer' => 'https://legacy.example.com',
        'client_id' => 'legacy-id',
        'client_auth_method' => 'secret'
      )
    end
  end

  describe 'disabled' do
    it 'returns an empty list when OIDC is off and no registry is set' do
      expect(build('VULCAN_ENABLE_OIDC' => 'false')).to eq([])
      expect(build({})).to eq([])
    end
  end

  describe 'key validation (fail loudly at boot)' do
    it 'rejects a key that is not lowercase snake_case' do
      ['Okta', 'login.gov', 'login-gov', 'okta!', 'UPPER'].each do |bad|
        expect { build('VULCAN_OIDC_PROVIDERS' => bad) }
          .to raise_error(ArgumentError, /Invalid VULCAN_OIDC_PROVIDERS key/)
      end
    end

    it 'accepts lowercase snake_case keys' do
      expect { build('VULCAN_OIDC_PROVIDERS' => 'okta,login_gov,idp2') }.not_to raise_error
    end
  end

  describe 'discovery default' do
    it 'defaults discovery to true and honors an explicit false' do
      on = build('VULCAN_OIDC_PROVIDERS' => 'a', 'VULCAN_OIDC_A_ISSUER_URL' => 'x').first
      off = build('VULCAN_OIDC_PROVIDERS' => 'a', 'VULCAN_OIDC_A_DISCOVERY' => 'false').first
      expect(on['discovery']).to be(true)
      expect(off['discovery']).to be(false)
    end
  end

  # Transforms a flat provider config into the nested args omniauth_openid_connect
  # expects. The flat shape is what build/Settings.oidc.providers store; devise.rb
  # passes the result straight to config.omniauth :openid_connect. Best-practice
  # details verified against devise-5.0.4 + omniauth_openid_connect-0.6.1 source:
  # explicit name:/strategy_class: (the multi-instance pattern), and the strategy
  # self-generates the nonce via send_nonce (there is no :nonce option).
  describe '.omniauth_args' do
    let(:okta) do
      described_class.from_env(
        'VULCAN_OIDC_PROVIDERS' => 'okta',
        'VULCAN_OIDC_OKTA_ISSUER_URL' => 'https://org.okta.com/oauth2/default',
        'VULCAN_OIDC_OKTA_CLIENT_ID' => 'okta-id',
        'VULCAN_OIDC_OKTA_CLIENT_SECRET' => 'okta-secret',
        'VULCAN_OIDC_OKTA_HOST' => 'org.okta.com',
        'VULCAN_OIDC_OKTA_REDIRECT_URI' => 'https://vulcan.example/users/auth/okta/callback',
        'VULCAN_OIDC_OKTA_TOKEN_URL' => 'https://org.okta.com/oauth2/v1/token'
      ).first
    end

    it 'pins the strategy with an explicit per-provider name and strategy_class' do
      args = described_class.omniauth_args(okta)
      expect(args).to include(
        name: :okta,
        strategy_class: OmniAuth::Strategies::OpenIDConnect,
        scope: %i[openid email profile],
        uid_field: 'sub',
        response_type: :code,
        discovery: true,
        issuer: 'https://org.okta.com/oauth2/default',
        client_auth_method: :secret,
        client_signing_alg: :RS256
      )
    end

    it 'nests connection settings (identifier/secret/host/endpoints) under client_options' do
      client_options = described_class.omniauth_args(okta)[:client_options]
      expect(client_options).to include(
        identifier: 'okta-id',
        secret: 'okta-secret',
        host: 'org.okta.com',
        scheme: 'https',
        port: 443,
        redirect_uri: 'https://vulcan.example/users/auth/okta/callback',
        token_endpoint: 'https://org.okta.com/oauth2/v1/token'
      )
    end

    it 'relies on the strategy-generated nonce (send_nonce) and omits the dead :nonce option' do
      args = described_class.omniauth_args(okta)
      expect(args[:send_nonce]).to be(true)
      expect(args).not_to have_key(:nonce)
    end

    it 'passes login.gov jwt_bearer + acr_values through for per-provider client auth' do
      login_gov = described_class.from_env(
        'VULCAN_OIDC_PROVIDERS' => 'login_gov',
        'VULCAN_OIDC_LOGIN_GOV_ISSUER_URL' => 'https://idp.int.identitysandbox.gov',
        'VULCAN_OIDC_LOGIN_GOV_CLIENT_AUTH_METHOD' => 'jwt_bearer',
        'VULCAN_OIDC_LOGIN_GOV_PRIVATE_KEY' => OpenSSL::PKey::RSA.generate(2048).to_pem,
        'VULCAN_OIDC_LOGIN_GOV_ACR_VALUES' => 'urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo'
      ).first
      args = described_class.omniauth_args(login_gov)
      expect(args[:client_auth_method]).to eq(:jwt_bearer)
      expect(args[:acr_values]).to eq('urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo')
      expect(args[:client_options][:private_key]).to be_a(OpenSSL::PKey::RSA)
    end
  end

  # Resolves a provider's display title from the live registry. One source of
  # truth shared by the login buttons and the OmniAuth callback flashes so a
  # configured title is shown consistently instead of an upcased strategy name.
  describe '.provider_origins' do
    before do
      allow(Settings).to receive(:oidc).and_return(
        double(
          'oidc',
          providers: [
            { 'name' => 'okta', 'issuer' => 'https://org.okta.com/oauth2/default' },
            { 'name' => 'login_gov', 'issuer' => 'https://idp.int.identitysandbox.gov' },
            { 'name' => 'dup', 'issuer' => 'https://org.okta.com/another' }
          ]
        )
      )
    end

    it 'returns deduplicated scheme://host origins for all configured providers' do
      expect(described_class.provider_origins).to contain_exactly(
        'https://org.okta.com',
        'https://idp.int.identitysandbox.gov'
      )
    end

    it 'skips providers with nil/blank issuers' do
      allow(Settings).to receive(:oidc).and_return(
        double('oidc', providers: [{ 'name' => 'blank', 'issuer' => nil }])
      )
      expect(described_class.provider_origins).to eq([])
    end
  end

  describe '.title_for' do
    before do
      allow(Settings).to receive(:oidc).and_return(
        double(
          'oidc',
          providers: [
            { 'name' => 'okta', 'title' => 'Okta SSO' },
            { 'name' => 'login_gov', 'title' => 'login.gov' }
          ]
        )
      )
    end

    it 'returns the configured title for a known provider given a string or symbol' do
      expect(described_class.title_for('okta')).to eq('Okta SSO')
      expect(described_class.title_for(:login_gov)).to eq('login.gov')
    end

    it 'falls back to a titleized name for a provider outside the OIDC registry' do
      expect(described_class.title_for(:github)).to eq('Github')
    end
  end
end
