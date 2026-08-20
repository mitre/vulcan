# frozen_string_literal: true

require 'rails_helper'
require 'openssl'

# jwt_bearer client auth for login.gov: when client_auth_method is jwt_bearer,
# omniauth_args must load the RSA private key (from inline PEM or file path)
# and include it as client_options[:private_key]. rack-oauth2 uses it to sign
# the client assertion JWT on the token exchange.
RSpec.describe OidcProviderRegistry, '.omniauth_args jwt_bearer' do
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:pem) { rsa_key.to_pem }

  def provider_with(overrides = {})
    {
      'name' => 'login_gov',
      'issuer' => 'https://idp.int.identitysandbox.gov',
      'client_id' => 'urn:gov:gsa:openidconnect:vulcan',
      'client_auth_method' => 'jwt_bearer',
      'client_signing_alg' => 'RS256',
      'discovery' => true,
      'host' => 'idp.int.identitysandbox.gov',
      'port' => 443,
      'scheme' => 'https'
    }.merge(overrides)
  end

  context 'with inline PEM (VULCAN_OIDC_<KEY>_PRIVATE_KEY)' do
    it 'parses the PEM and includes the RSA key in client_options[:private_key]' do
      args = described_class.omniauth_args(provider_with('private_key' => pem))
      expect(args[:client_options][:private_key]).to be_a(OpenSSL::PKey::RSA)
      expect(args[:client_options][:private_key].to_pem).to eq(pem)
    end
  end

  context 'with key file path (VULCAN_OIDC_<KEY>_PRIVATE_KEY_PATH)' do
    it 'reads and parses the key from the file' do
      Tempfile.create(['test_key', '.pem']) do |f|
        f.write(pem)
        f.flush
        args = described_class.omniauth_args(provider_with('private_key_path' => f.path))
        expect(args[:client_options][:private_key]).to be_a(OpenSSL::PKey::RSA)
      end
    end
  end

  context 'when jwt_bearer but no key provided' do
    it 'raises ArgumentError with an actionable message at boot' do
      expect { described_class.omniauth_args(provider_with) }
        .to raise_error(ArgumentError, /private key.*login_gov/i)
    end
  end

  context 'with an unparseable key' do
    it 'raises ArgumentError with the provider name' do
      expect { described_class.omniauth_args(provider_with('private_key' => 'not-a-pem')) }
        .to raise_error(ArgumentError, /login_gov/i)
    end
  end

  context 'when client_auth_method is secret (default)' do
    it 'does NOT include private_key in client_options' do
      secret_provider = provider_with('client_auth_method' => 'secret', 'client_secret' => 's3cret')
      args = described_class.omniauth_args(secret_provider)
      expect(args[:client_options]).not_to have_key(:private_key)
    end
  end
end
