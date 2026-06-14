# frozen_string_literal: true

require 'rails_helper'

# Backward compatibility for the multi-provider login page: when no registry is
# configured, Settings.oidc.providers holds a single `oidc` provider and the
# login page must render exactly one OIDC button, labeled with the configured
# title and linking to /users/auth/oidc — unchanged from the pre-registry view.
#
# The N-button multi-provider rendering is proven by the live boot (Playwright),
# because the per-provider routes only exist when those strategies are
# registered at boot; the test environment registers the single `oidc` provider.
RSpec.describe 'OIDC login buttons' do
  before { Rails.application.reload_routes! }

  it 'renders the single legacy OIDC button with the configured title and auth path' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    # Sanity: the test environment really does register the legacy oidc strategy,
    # so the assertions below are meaningful rather than vacuously skipped.
    expect(Devise.omniauth_providers).to include(:oidc)
    expect(response.body).to include("Sign in with #{Settings.oidc.title}")
    expect(response.body).to include('/users/auth/oidc')
  end
end
