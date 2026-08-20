# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OIDC login buttons' do
  before { Rails.application.reload_routes! }

  # The login page renders one button per registered OIDC provider, titled from
  # the registry (OidcProviderRegistry.title_for). Driving the expectation from
  # Settings.oidc.providers pins the page-to-registry correspondence in every
  # environment — local multi-provider registries and CI's legacy single
  # provider alike — instead of encoding one machine's configuration.
  it 'renders a button with the registry title and auth path for every configured provider' do
    providers = Array(Settings.oidc&.providers).pluck('name')
    skip 'No OIDC provider registered in this test environment' if providers.empty?

    get new_user_session_path

    expect(response).to have_http_status(:ok)
    providers.each do |name|
      expect(Devise.omniauth_providers).to include(name.to_sym)
      expect(response.body).to include("Sign in with #{OidcProviderRegistry.title_for(name)}")
      expect(response.body).to include("/users/auth/#{name}")
    end
  end
end
