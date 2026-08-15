# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Docs' do
  let(:user) { create(:user) }

  before { Rails.application.reload_routes! }

  # The CDN-loaded viewer is gone: it fetched its script and the specification
  # from external origins, so an airgapped deployment rendered an empty page.
  # The reference now ships inside the built documentation site, and the old
  # URL forwards readers there permanently.
  describe 'GET /api/docs' do
    it 'permanently redirects to the API reference in the documentation site' do
      get '/api/docs'
      expect(response).to have_http_status(:moved_permanently)
      expect(response.headers['Location']).to end_with('/docs/api/overview')
    end
  end

  describe 'the API reference inside the built documentation site' do
    before(:all) { DocsSiteHelpers.require_built_site! }

    it 'serves a known operation page from the build with no CDN reference' do
      get '/docs/api/operations/listProjects'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('List accessible projects')
      expect(response.body).not_to include('cdn.jsdelivr.net')
    end
  end

  # The machine-readable specification lives at the OpenAPI-recommended root
  # filenames, independent of the browser viewer's fate. Tooling guesses
  # these paths first; the old viewer-nested paths redirect permanently and
  # NEVER answer a spec request with HTML.
  describe 'machine-readable specification at recommended root filenames' do
    before { sign_in user }

    it 'serves a parseable YAML document at /openapi.yaml' do
      get '/openapi.yaml'
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('yaml')
      parsed = YAML.safe_load(response.body, permitted_classes: [Date, Time])
      expect(parsed['info']['title']).to eq('Vulcan API')
      expect(parsed['openapi']).to start_with('3.')
    end

    it 'serves a parseable JSON document at /openapi.json' do
      get '/openapi.json'
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      parsed = response.parsed_body
      expect(parsed['info']['title']).to eq('Vulcan API')
      expect(parsed['openapi']).to start_with('3.')
    end

    describe 'the previously served paths' do
      {
        '/api/docs/openapi.yaml' => '/openapi.yaml',
        '/api/docs/openapi.yml' => '/openapi.yaml',
        '/api/docs/openapi.json' => '/openapi.json'
      }.each do |old_path, new_path|
        it "permanently redirects #{old_path} to #{new_path}" do
          get old_path
          expect(response).to have_http_status(:moved_permanently)
          expect(response.headers['Location']).to end_with(new_path)
        end
      end
    end
  end
end
