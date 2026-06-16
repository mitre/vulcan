# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionsHelper do
  # The login view loops Devise.omniauth_providers (provider symbols) and labels
  # each button by title. With multiple OIDC providers the title must come from
  # the per-provider registry, not a single global Settings.oidc.title.
  describe '#oauth_provider_title' do
    before do
      allow(Settings).to receive(:oidc).and_return(
        double(
          'oidc',
          providers: [
            { 'name' => 'okta', 'title' => 'Okta SSO' },
            { 'name' => 'oidc', 'title' => 'Company SSO' }
          ]
        )
      )
    end

    it 'labels each provider with its own configured title from the registry' do
      expect(helper.oauth_provider_title(:okta)).to eq('Okta SSO')
      expect(helper.oauth_provider_title(:oidc)).to eq('Company SSO')
    end

    it 'falls back to a titleized name for a provider outside the OIDC registry' do
      expect(helper.oauth_provider_title(:github)).to eq('Github')
    end
  end
end
