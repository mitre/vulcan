# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'

# Validates that actual API responses match the OpenAPI 3.2 spec schemas.
# These are the real contract tests — they hit live endpoints and check
# the response body against doc/openapi.yaml.
RSpec.describe 'OpenAPI contract validation', type: :request do
  include Devise::Test::IntegrationHelpers

  before { Rails.application.reload_routes! } # rubocop:disable RSpec/ScatteredSetup

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:project) { create(:project, name: 'Contract Test Project') }
  let_it_be(:component) { create(:component, project: project, based_on: srg, name: 'Contract Component') }
  let_it_be(:membership) do
    Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
      m.role = 'admin'
    end
  end

  let(:vulcan_api) { OpenapiFirst::Test.definitions[:vulcan] }

  def validate_response!(req, resp)
    validated = vulcan_api.validate_response(req, resp, raise_error: false)
    return if validated.valid?

    raise "Contract violation on #{req.method} #{req.path} (#{resp.status}):\n#{validated.error.message}"
  end

  before { sign_in admin } # rubocop:disable RSpec/ScatteredSetup

  describe 'GET /api/version' do
    it 'matches VersionResponse schema' do
      get '/api/version', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to have_key('version')
      expect(body).to have_key('rails')
      expect(body).to have_key('ruby')
    end
  end

  describe 'GET /api/search/global' do
    it 'matches GlobalSearchResponse schema' do
      get '/api/search/global', params: { q: 'Contract' }, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to have_key('projects')
      expect(body).to have_key('components')
      expect(body).to have_key('rules')
      expect(body).to have_key('srgs')
      expect(body).to have_key('stigs')
    end
  end

  describe 'GET /projects (JSON)' do
    it 'matches ProjectSummary array schema' do
      get '/projects', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)
    end
  end

  describe 'GET /projects/:id (JSON)' do
    it 'matches ProjectSummary schema' do
      get "/projects/#{project.id}", headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)
    end
  end

  describe 'GET /components/:id (JSON)' do
    it 'matches ComponentSummary schema' do
      get "/components/#{component.id}", headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)
    end
  end

  describe 'GET /components/:id/comments' do
    it 'matches PaginatedComments schema' do
      get "/components/#{component.id}/comments", headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to have_key('rows')
      expect(body).to have_key('pagination')
      expect(body).to have_key('status_counts')
    end
  end

  describe 'GET /srgs (JSON)' do
    it 'matches BenchmarkSummary array schema and validates contract' do
      get '/srgs', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to be_an(Array)
      expect(body.first).to have_key('id') if body.any?
    end
  end

  describe 'GET /stigs (JSON)' do
    it 'matches BenchmarkSummary array schema and validates contract' do
      get '/stigs', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to be_an(Array)
    end
  end

  describe 'GET /users (JSON)' do
    it 'matches UserSummary array schema and validates contract' do
      get '/users', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to be_an(Array)
      expect(body.first).to have_key('id')
      expect(body.first).to have_key('email')
    end
  end

  describe 'POST /projects (toast response)' do
    it 'matches ToastResponse schema on success' do
      post '/projects',
           params: { project: { name: 'Contract Toast Test', description: 'test' } },
           headers: { 'Accept' => 'application/json' },
           as: :json
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body.dig('toast', 'title')).to be_a(String)
    end
  end
end
