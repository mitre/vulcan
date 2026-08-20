# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Devise Passwords JSON', openapi: false do
  include Devise::Test::IntegrationHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user, password: 'S3cure!#Pass999') }

  let(:json_headers) { { 'Accept' => 'application/json' } }

  describe 'POST /users/password (request reset)' do
    it 'returns 200 with toast for known email' do
      post '/users/password',
           params: { user: { email: user.email } },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to be_present
    end

    it 'returns 200 with toast for unknown email (paranoid mode)' do
      post '/users/password',
           params: { user: { email: 'nonexistent@example.com' } },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
    end

    it 'returns 422 when email param is blank' do
      post '/users/password',
           params: { user: { email: '' } },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message')).to include("Email can't be blank")
    end
  end

  describe 'PUT /users/password (execute reset)' do
    it 'returns 200 with toast for valid reset' do
      token = user.send_reset_password_instructions

      put '/users/password',
          params: { user: { reset_password_token: token,
                            password: 'N3wS3cure!#Pass',
                            password_confirmation: 'N3wS3cure!#Pass' } },
          headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
    end

    it 'returns 422 with toast for invalid token' do
      put '/users/password',
          params: { user: { reset_password_token: 'badtoken',
                            password: 'N3wS3cure!#Pass',
                            password_confirmation: 'N3wS3cure!#Pass' } },
          headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message')).to include('Reset password token is invalid')
    end

    it 'returns 422 when passwords do not match' do
      token = user.send_reset_password_instructions

      put '/users/password',
          params: { user: { reset_password_token: token,
                            password: 'NewS3cure!#Pass',
                            password_confirmation: 'Mismatch!#Pass' } },
          headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
    end
  end

  describe 'GET /users/password/edit (validate reset token)' do
    it 'returns 200 with valid token info' do
      token = user.send_reset_password_instructions

      get '/users/password/edit',
          params: { reset_password_token: token },
          headers: json_headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['valid']).to be(true)
      expect(body['minimum_password_length']).to be_a(Integer)
    end

    it 'returns 422 for invalid token' do
      get '/users/password/edit',
          params: { reset_password_token: 'badtoken' },
          headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body['valid']).to be(false)
    end

    it 'returns 422 when no token provided' do
      get '/users/password/edit',
          headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body['valid']).to be(false)
    end
  end
end
