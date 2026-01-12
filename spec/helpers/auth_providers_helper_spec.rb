# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthProvidersHelper, type: :helper do
  describe '#auth_providers' do
    context 'when no providers are enabled' do
      before do
        allow(Settings.ldap).to receive(:enabled).and_return(false)
        allow(Settings.oidc).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:providers).and_return(nil)
      end

      it 'returns empty array' do
        expect(helper.auth_providers).to eq([])
      end
    end

    context 'when only LDAP is enabled' do
      before do
        ldap_settings = double('ldap_settings', enabled: true)
        ldap_servers = double('ldap_servers')
        ldap_main = double('ldap_main', title: 'Corporate LDAP')

        allow(Settings).to receive(:ldap).and_return(ldap_settings)
        allow(ldap_settings).to receive(:servers).and_return(ldap_servers)
        allow(ldap_servers).to receive(:main).and_return(ldap_main)
        allow(Settings.oidc).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:providers).and_return(nil)
      end

      it 'returns LDAP provider' do
        result = helper.auth_providers

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result[0]).to eq({
          id: 'ldap',
          title: 'Corporate LDAP',
          path: '/users/auth/ldap',
        })
      end
    end

    context 'when only OIDC is enabled' do
      before do
        oidc_settings = double('oidc_settings', enabled: true, title: 'Okta')

        allow(Settings.ldap).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:oidc).and_return(oidc_settings)
        allow(Settings).to receive(:providers).and_return(nil)
      end

      it 'returns OIDC provider' do
        result = helper.auth_providers

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result[0]).to eq({
          id: 'oidc',
          title: 'Okta',
          path: '/users/auth/oidc',
        })
      end
    end

    context 'when LDAP and OIDC are both enabled' do
      before do
        ldap_settings = double('ldap_settings', enabled: true)
        ldap_servers = double('ldap_servers')
        ldap_main = double('ldap_main', title: 'Corporate LDAP')
        oidc_settings = double('oidc_settings', enabled: true, title: 'Okta')

        allow(Settings).to receive(:ldap).and_return(ldap_settings)
        allow(ldap_settings).to receive(:servers).and_return(ldap_servers)
        allow(ldap_servers).to receive(:main).and_return(ldap_main)
        allow(Settings).to receive(:oidc).and_return(oidc_settings)
        allow(Settings).to receive(:providers).and_return(nil)
      end

      it 'returns both providers in order' do
        result = helper.auth_providers

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0][:id]).to eq('ldap')
        expect(result[1][:id]).to eq('oidc')
      end
    end

    context 'when generic OAuth providers are configured' do
      let(:github_provider) do
        {
          name: 'github',
          title: 'Sign in with GitHub',
          app_id: 'test_id',
          app_secret: 'test_secret',
        }
      end

      let(:google_provider) do
        {
          name: 'google',
          app_id: 'test_id',
          app_secret: 'test_secret',
        }
      end

      before do
        allow(Settings.ldap).to receive(:enabled).and_return(false)
        allow(Settings.oidc).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:providers).and_return([github_provider, google_provider])
      end

      it 'returns generic OAuth providers' do
        result = helper.auth_providers

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        # GitHub with explicit title
        expect(result[0]).to eq({
          id: 'github',
          title: 'Sign in with GitHub',
          path: '/users/auth/github',
        })

        # Google without title (uses default)
        expect(result[1]).to eq({
          id: 'google',
          title: 'Sign in with Google',
          path: '/users/auth/google',
        })
      end
    end

    context 'when all provider types are enabled' do
      let(:gitlab_provider) do
        {
          name: 'gitlab',
          title: 'Corporate GitLab',
          app_id: 'test_id',
          app_secret: 'test_secret',
        }
      end

      before do
        ldap_settings = double('ldap_settings', enabled: true)
        ldap_servers = double('ldap_servers')
        ldap_main = double('ldap_main', title: 'LDAP')
        oidc_settings = double('oidc_settings', enabled: true, title: 'Okta')

        allow(Settings).to receive(:ldap).and_return(ldap_settings)
        allow(ldap_settings).to receive(:servers).and_return(ldap_servers)
        allow(ldap_servers).to receive(:main).and_return(ldap_main)
        allow(Settings).to receive(:oidc).and_return(oidc_settings)
        allow(Settings).to receive(:providers).and_return([gitlab_provider])
      end

      it 'returns all providers in order: LDAP, OIDC, OAuth' do
        result = helper.auth_providers

        expect(result).to be_an(Array)
        expect(result.length).to eq(3)
        expect(result[0][:id]).to eq('ldap')
        expect(result[1][:id]).to eq('oidc')
        expect(result[2][:id]).to eq('gitlab')
      end
    end

    context 'when LDAP has no title configured' do
      before do
        ldap_settings = double('ldap_settings', enabled: true)
        ldap_servers = double('ldap_servers')
        ldap_main = double('ldap_main', title: nil)

        allow(Settings).to receive(:ldap).and_return(ldap_settings)
        allow(ldap_settings).to receive(:servers).and_return(ldap_servers)
        allow(ldap_servers).to receive(:main).and_return(ldap_main)
        allow(Settings.oidc).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:providers).and_return(nil)
      end

      it 'uses default LDAP title' do
        result = helper.auth_providers

        expect(result[0][:title]).to eq('LDAP')
      end
    end

    context 'when OIDC has no title configured' do
      before do
        oidc_settings = double('oidc_settings', enabled: true, title: nil)

        allow(Settings.ldap).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:oidc).and_return(oidc_settings)
        allow(Settings).to receive(:providers).and_return(nil)
      end

      it 'uses default OIDC title' do
        result = helper.auth_providers

        expect(result[0][:title]).to eq('OIDC Provider')
      end
    end

    context 'when Settings.providers is empty array' do
      before do
        allow(Settings.ldap).to receive(:enabled).and_return(false)
        allow(Settings.oidc).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:providers).and_return([])
      end

      it 'returns empty array' do
        expect(helper.auth_providers).to eq([])
      end
    end

    context 'with multiple OAuth providers of different types' do
      let(:providers_list) do
        [
          { name: 'github', title: 'GitHub' },
          { name: 'google', title: 'Google' },
          { name: 'gitlab', title: 'GitLab' },
          { name: 'azure_activedirectory_v2', title: 'Microsoft Azure AD' },
        ]
      end

      before do
        allow(Settings.ldap).to receive(:enabled).and_return(false)
        allow(Settings.oidc).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:providers).and_return(providers_list)
      end

      it 'returns all providers with correct paths' do
        result = helper.auth_providers

        expect(result.length).to eq(4)
        expect(result.map { |p| p[:id] }).to eq(%w[github google gitlab azure_activedirectory_v2])
        expect(result.map { |p| p[:path] }).to eq([
          '/users/auth/github',
          '/users/auth/google',
          '/users/auth/gitlab',
          '/users/auth/azure_activedirectory_v2',
        ])
      end
    end
  end
end
