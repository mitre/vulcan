# frozen_string_literal: true

require 'rails_helper'

##
# The readers who most need the deployment and troubleshooting pages are the
# ones who cannot sign in — a fresh install with no administrator yet, a
# misconfigured identity provider, an operator in an airgapped environment. The
# sign-in page offers the documentation to them, but only where it is actually
# reachable without a session: a link to a login-gated page, shown on the login
# page, is worse than no link.
#
RSpec.describe 'Sign-in page documentation link' do
  # Scoped to spec/config/ by default; the access setting is driven through its
  # real environment variable rather than stubbed.
  include SettingsEnvHelpers

  # The reachability example follows the link into the served site.
  before(:all) { DocsSiteHelpers.require_built_site! }

  before do
    Rails.application.reload_routes!
  end

  it 'offers the documentation when it is public' do
    get '/users/sign_in'

    expect(response.body).to include('href="/docs"')
  end

  it 'links somewhere an anonymous visitor can actually reach' do
    get '/users/sign_in'
    expect(response.body).to include('href="/docs"')

    get '/docs'

    expect(response).to have_http_status(:ok)
  end

  it 'omits the link when the deployment requires a login for documentation' do
    with_settings_env(VULCAN_DOCS_REQUIRE_LOGIN: 'true') do
      get '/users/sign_in'

      expect(response.body).not_to include('href="/docs"')
    end
  end

  it 'still renders the sign-in form alongside the link' do
    get '/users/sign_in'

    expect(response.body).to include('Welcome to Vulcan')
    expect(response.body).to include('name="user[email]"')
  end
end
