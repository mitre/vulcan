# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Auth' do
  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user, email: 'test@example.com', password: 'S3cure!#Pass999') }

  describe 'GET /api/auth/me' do
    context 'when authenticated' do
      before { sign_in user }

      it 'returns current user identity with admin status' do
        get '/api/auth/me', as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['id']).to eq(user.id)
        expect(body['name']).to eq(user.name)
        expect(body['email']).to eq(user.email)
        expect(body['admin']).to be(false)
      end

      it 'returns admin=true for admin users' do
        sign_in anchor_admin
        get '/api/auth/me', as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['admin']).to be(true)
      end

      it 'does NOT include sensitive fields (encrypted_password, reset_password_token)' do
        get '/api/auth/me', as: :json

        body = response.parsed_body
        expect(body).not_to have_key('encrypted_password')
        expect(body).not_to have_key('reset_password_token')
        expect(body).not_to have_key('confirmation_token')
      end
    end

    context 'when not authenticated' do
      it 'returns 401 JSON' do
        get '/api/auth/me', as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['error']).to eq('Unauthorized')
      end
    end
  end

  describe 'POST /api/auth/login' do
    it 'authenticates with valid email and password' do
      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['id']).to eq(user.id)
      expect(body['name']).to eq(user.name)
      expect(body['email']).to eq(user.email)
    end

    it 'returns 401 for invalid credentials' do
      post '/api/auth/login', params: { email: user.email, password: 'wrong' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['error']).to be_present
    end

    it 'returns 401 for non-existent email' do
      post '/api/auth/login', params: { email: 'nobody@example.com', password: 'anything' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'sets a session so subsequent /me calls succeed' do
      post '/api/auth/login', params: { email: user.email, password: 'S3cure!#Pass999' }, as: :json
      expect(response).to have_http_status(:ok)

      get '/api/auth/me', as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(user.id)
    end
  end

  describe 'DELETE /api/auth/logout' do
    before { sign_in user }

    it 'destroys the session and returns 200' do
      delete '/api/auth/logout', as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['message']).to include('Signed out')
    end

    it 'subsequent /me call returns 401' do
      delete '/api/auth/logout', as: :json
      expect(response).to have_http_status(:ok)

      get '/api/auth/me', as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
