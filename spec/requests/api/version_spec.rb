# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Version Endpoint' do
  # REQUIREMENT: GET /api/version returns application metadata as JSON.
  # No authentication required — used by monitoring, deployment verification,
  # and the frontend to display current version.

  before { Rails.application.reload_routes! }

  describe 'GET /api/version' do
    it 'returns 200 without authentication' do
      get '/api/version'
      expect(response).to have_http_status(:ok)
    end

    it 'returns JSON content type' do
      get '/api/version'
      expect(response.content_type).to include('application/json')
    end

    it 'includes the application version from Vulcan::VERSION' do
      get '/api/version'
      json = response.parsed_body
      expect(json['version']).to eq(Vulcan::VERSION)
    end

    it 'includes the application name' do
      get '/api/version'
      json = response.parsed_body
      expect(json['name']).to eq('Vulcan')
    end

    it 'includes Rails version' do
      get '/api/version'
      json = response.parsed_body
      expect(json['rails']).to eq(Rails.version)
    end

    it 'includes Ruby version' do
      get '/api/version'
      json = response.parsed_body
      expect(json['ruby']).to eq(RUBY_VERSION)
    end

    it 'includes the current environment' do
      get '/api/version'
      json = response.parsed_body
      expect(json['environment']).to eq(Rails.env)
    end
  end
end
