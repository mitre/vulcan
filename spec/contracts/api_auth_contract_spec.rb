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

  describe 'GET /api/auth/csrf (no session)' do
    it 'issues a session-bound token without authentication and forbids caching' do
      get '/api/auth/csrf', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :csrf_token
      expect(body['csrf_token']).to be_present
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(request.session[:_csrf_token]).to be_present
    end
  end

  # config/environments/test.rb disables forgery protection suite-wide, so
  # these examples turn it on for their duration; otherwise the contract
  # would never show that the issued token is the one the login accepts.
  describe 'GET /api/auth/csrf with forgery protection on' do
    around do |example|
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = previous
    end

    it 'refuses a login that carries no token and leaves the caller signed out' do
      post '/api/auth/login',
           params: { email: user.email, password: 'S3cure!#Pass999' },
           headers: json_headers, as: :json
      # ApplicationController rescues StandardError outside development with
      # helpful_errors, which renders a JSON toast with status 500, so an
      # InvalidAuthenticityToken surfaces as 500 here, not Rails' default 422.
      # A dedicated 422 problem+json for forgery failures is a separate change.
      expect(response).to have_http_status(:internal_server_error)
      expect(response.parsed_body.dig('toast', 'variant')).to eq('danger')

      get '/api/auth/me', headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'accepts a login that carries the issued token' do
      get '/api/auth/csrf', headers: json_headers
      token = response.parsed_body['csrf_token']

      post '/api/auth/login',
           params: { email: user.email, password: 'S3cure!#Pass999' },
           headers: json_headers.merge('X-CSRF-Token' => token), as: :json
      body = validate_and_parse!

      expect(body['id']).to eq(user.id)
    end
  end

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

      expect(body['type']).to eq('/docs/api/errors#not_authenticated')
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

      expect(body['type']).to eq('/docs/api/errors#invalid_credentials')
      expect(body['detail']).to eq('The email or password is incorrect.')
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
