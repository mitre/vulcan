# frozen_string_literal: true

require 'rails_helper'

##
# The documentation site is served by the application rather than from public/,
# so that access can be governed by a setting. These examples pin the serving
# behaviour: what comes back, what does not, and what a request cannot reach.
#
RSpec.describe 'Docs site' do
  # Scoped to spec/config/ by default. The access setting is a deployment-facing
  # contract, so it is exercised through the real environment variable rather
  # than by stubbing the Settings object.
  include SettingsEnvHelpers

  before do
    Rails.application.reload_routes!
  end

  describe 'serving the build' do
    it 'serves the built documentation index' do
      get '/docs'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(response.body).to include('<title>Vulcan</title>')
    end

    it 'resolves a nested page requested without its extension' do
      get '/docs/disa-process/overview'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(response.body).to include('DISA')
    end

    # Rails refuses to serve JavaScript to a plain GET unless the same-origin
    # check is skipped, which returned 422 for every bundle and left the site
    # unable to hydrate. This is the guard for that.
    it 'serves the site JavaScript rather than refusing it as a cross-origin script' do
      asset = Dir.glob(DocsSite.output_directory.join('assets/*.js')).first
      request_path = "/docs/assets/#{File.basename(asset)}"

      get request_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/javascript')
    end

    it 'serves the site stylesheet' do
      asset = Dir.glob(DocsSite.output_directory.join('assets/*.css')).first

      get "/docs/assets/#{File.basename(asset)}"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/css')
    end

    it 'returns 404 for a page the site does not contain' do
      get '/docs/no-such-page'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'containment' do
    it 'refuses to read outside the build directory' do
      get '/docs/..%2f..%2fconfig/database.yml'

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('adapter')
    end

    it 'refuses a traversal expressed in path segments' do
      get '/docs/a/../../../config/database.yml'

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('adapter')
    end
  end

  describe 'access' do
    it 'is public by default' do
      get '/docs'

      expect(response).to have_http_status(:ok)
    end

    context 'when the deployment requires a login for documentation' do
      it 'sends an anonymous visitor to sign in' do
        with_settings_env(VULCAN_DOCS_REQUIRE_LOGIN: 'true') do
          get '/docs'

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      it 'serves the site to a signed-in user' do
        user = create(:user)

        with_settings_env(VULCAN_DOCS_REQUIRE_LOGIN: 'true') do
          sign_in user
          get '/docs'

          expect(response).to have_http_status(:ok)
          expect(response.body).to include('<title>Vulcan</title>')
        end
      end
    end
  end
end
