# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OIDC login buttons' do
  before { Rails.application.reload_routes! }

  let(:provider) { Devise.omniauth_providers.first }

  it 'renders the OIDC button with the configured title and auth path' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(Devise.omniauth_providers).to include(provider)
    expect(response.body).to include("Sign in with #{Settings.oidc.title}")
      .or include("Sign in with #{OidcProviderRegistry.title_for(provider)}")
    expect(response.body).to include("/users/auth/#{provider}")
  end
end
