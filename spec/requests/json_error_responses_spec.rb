# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JSON error responses' do
  include Devise::Test::IntegrationHelpers

  let_it_be(:admin) { create(:user, admin: true) }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  describe '404 Not Found' do
    it 'returns JSON body for missing project' do
      get '/projects/999999', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include('application/json')
      expect(response.parsed_body).to have_key('error')
    end

    it 'returns JSON body for missing rule' do
      get '/rules/999999', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include('application/json')
      expect(response.parsed_body['error']).to eq('Not found')
    end

    it 'returns JSON body for missing SRG' do
      get '/srgs/999999', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include('application/json')
    end

    it 'returns JSON body for missing STIG' do
      get '/stigs/999999', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include('application/json')
    end

    it 'returns JSON body for missing review responses' do
      get '/reviews/999999/responses', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include('application/json')
    end
  end

  describe '404 via token auth' do
    it 'returns JSON body for missing resource via API token' do
      token = create(:personal_access_token, user: admin, scopes: %w[read])

      get '/rules/999999',
          headers: { 'Authorization' => "Token #{token.raw_token}", 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include('application/json')
      expect(response.parsed_body['error']).to eq('Not found')
    end
  end
end
