# frozen_string_literal: true

require 'rails_helper'

# The discovery-document validator compares the IdP's declared issuer against
# the configured issuer. Configured issuers are normalized (trailing slash
# stripped) before the comparison, but IdPs like login.gov declare their
# canonical issuer WITH a trailing slash — the comparison must treat those as
# the same issuer or every login logs a spurious SECURITY_ERROR and the
# discovery cache never populates.
RSpec.describe OidcDiscoveryHelper do
  let(:harness) do
    Class.new do
      include OidcDiscoveryHelper

      # The concern logs through the including controller's context.
      def log_oidc_discovery_event(*); end
    end.new
  end

  let(:base_document) do
    {
      'issuer' => 'https://idp.example.gov',
      'authorization_endpoint' => 'https://idp.example.gov/openid_connect/authorize',
      'response_types_supported' => ['code'],
      'subject_types_supported' => ['pairwise'],
      'id_token_signing_alg_values_supported' => ['RS256']
    }
  end

  describe '#validate_discovery_document' do
    it 'accepts a document whose issuer matches the expected issuer exactly' do
      expect do
        harness.send(:validate_discovery_document, base_document, 'https://idp.example.gov')
      end.not_to raise_error
    end

    it 'accepts a document whose issuer differs only by a trailing slash' do
      document = base_document.merge('issuer' => 'https://idp.example.gov/')

      expect do
        harness.send(:validate_discovery_document, document, 'https://idp.example.gov')
      end.not_to raise_error
    end

    it 'rejects a document issued by a different host' do
      document = base_document.merge('issuer' => 'https://evil.example.com')

      expect do
        harness.send(:validate_discovery_document, document, 'https://idp.example.gov')
      end.to raise_error(SecurityError, /Issuer mismatch/)
    end

    it 'rejects a document whose issuer only shares a prefix with the expected issuer' do
      document = base_document.merge('issuer' => 'https://idp.example.gov.evil.example.com')

      expect do
        harness.send(:validate_discovery_document, document, 'https://idp.example.gov')
      end.to raise_error(SecurityError, /Issuer mismatch/)
    end
  end
end
