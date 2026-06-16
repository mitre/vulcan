# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Navigation endpoint contract', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:admin) { create(:user, admin: true) }

  describe 'GET /api/navigation (authenticated admin)' do
    before { sign_in admin }

    it 'matches NavigationResponse schema' do
      get '/api/navigation', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :nav_links, :access_requests, :locked_users
      expect(body['nav_links']).to be_an(Array)
      expect(body['nav_links'].size).to be >= 5
      expect(body['access_requests']).to be_an(Array)
      expect(body['locked_users']).to be_an(Array)
    end
  end

  describe 'GET /api/navigation (unauthenticated)' do
    it 'returns 401 matching error schema' do
      get '/api/navigation', headers: json_headers
      body = validate_and_parse!(expected_status: :unauthorized)

      expect(body['error']).to eq('Unauthorized')
    end
  end
end
