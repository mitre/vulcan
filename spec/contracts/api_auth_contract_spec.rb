# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Auth endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user, password: 'S3cure!#Pass999') }

  describe 'GET /api/auth/me (authenticated)' do
    before { sign_in user }

    it 'matches CurrentUserResponse schema' do
      get '/api/auth/me', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :id, :name, :email, :admin
      assert_fields_absent body, :encrypted_password, :reset_password_token
      expect(body['id']).to eq(user.id)
      expect(body['email']).to eq(user.email)
      expect(body['admin']).to be(false)
    end
  end

  describe 'GET /api/auth/me (unauthenticated)' do
    it 'returns 401 matching error schema' do
      get '/api/auth/me', headers: json_headers
      body = validate_and_parse!(expected_status: :unauthorized)

      expect(body['error']).to eq('Unauthorized')
    end
  end

  describe 'POST /api/auth/login (valid credentials)' do
    it 'matches CurrentUserResponse schema' do
      post '/api/auth/login',
           params: { email: user.email, password: 'S3cure!#Pass999' },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :id, :name, :email, :admin
      expect(body['id']).to eq(user.id)
    end
  end

  describe 'POST /api/auth/login (invalid credentials)' do
    it 'returns 401 matching error schema' do
      post '/api/auth/login',
           params: { email: user.email, password: 'wrong' },
           headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unauthorized)

      expect(body['error']).to eq('Invalid email or password')
    end
  end

  describe 'DELETE /api/auth/logout (authenticated)' do
    before { sign_in user }

    it 'matches logout response schema' do
      delete '/api/auth/logout', headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body['message']).to eq('Signed out successfully')
    end
  end
end
