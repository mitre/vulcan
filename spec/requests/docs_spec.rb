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

  before(:all) { DocsSiteHelpers.require_built_site! }

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
      # The page's own title, not a string the shared navigation puts on every
      # page — this pins that THIS page came back, not merely some page.
      expect(response.body).to include('<title>DISA Vendor STIG Process | Vulcan</title>')
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

    # Head entries in the site configuration are emitted VERBATIM — VitePress
    # rebases markdown links and bundled assets under the base path, but not
    # these. A hardcoded root-absolute icon href renders fine on the published
    # site (base /) and 404s everywhere else, which is exactly what happened
    # to the favicon. Requesting every reference the served index makes keeps
    # that whole class caught.
    it 'serves every asset the built index references' do
      get '/docs'

      references = response.body.scan(%r{(?:href|src)="(/[^"]+)"}).flatten.uniq
      expect(references).not_to be_empty

      failures = references.reject do |path|
        get path
        response.status == 200
      end

      expect(failures).to eq([])
    end
  end

  describe 'containment' do
    # The traversal must aim at a file that really exists — the build root sits
    # three directories below the repo, and a 404 for a target that is not
    # there would still pass with the containment check deleted. Asserting the
    # target exists first is what makes the 404 attributable to containment.
    it 'refuses a traversal that reaches a real file outside the build' do
      expect(Rails.root.join('config/database.yml')).to exist

      get '/docs/..%2f..%2f..%2fconfig%2fdatabase.yml'

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq('Not found')
    end

    # A symlink inside the build pointing outside it must not be followed: the
    # containment comparison resolves real paths, so the link's target decides,
    # not where the link sits.
    it 'refuses to follow a symlink out of the build directory' do
      target = Rails.root.join('config/database.yml')
      link = DocsSite.output_directory.join('escape-hatch.yml')
      File.symlink(target, link)

      get '/docs/escape-hatch.yml'

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq('Not found')
    ensure
      File.delete(link) if File.symlink?(link)
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
