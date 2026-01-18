# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Password Resets', type: :request do
  before do
    Rails.application.reload_routes! # Required for Rails 8 lazy loading
  end

  describe 'GET /users/password/edit' do
    context 'when requesting JSON' do
      let(:user) { create(:user) }
      let(:token) { user.send_reset_password_instructions }

      it 'returns token validation success' do
        get '/users/password/edit',
            params: { reset_password_token: token },
            headers: { 'Accept' => 'application/json' },
            as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['valid']).to be true
      end

      it 'returns error for invalid token' do
        get '/users/password/edit',
            params: { reset_password_token: 'invalid-token' },
            headers: { 'Accept' => 'application/json' },
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
      end
    end
  end

  describe 'PUT /users/password' do
    context 'when requesting JSON' do
      let(:user) { create(:user) }
      let(:token) { user.send_reset_password_instructions }

      it 'updates password with valid token' do
        put '/users/password',
            params: {
              user: {
                reset_password_token: token,
                password: 'NewPassword123!',
                password_confirmation: 'NewPassword123!'
              }
            },
            headers: { 'Accept' => 'application/json' },
            as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['message']).to include('Password changed successfully')

        # Verify password was actually changed
        user.reload
        expect(user.valid_password?('NewPassword123!')).to be true
      end

      it 'returns error for mismatched passwords' do
        put '/users/password',
            params: {
              user: {
                reset_password_token: token,
                password: 'NewPassword123!',
                password_confirmation: 'DifferentPassword123!'
              }
            },
            headers: { 'Accept' => 'application/json' },
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['errors']).to be_present
      end

      it 'returns error for invalid token' do
        put '/users/password',
            params: {
              user: {
                reset_password_token: 'invalid-token',
                password: 'NewPassword123!',
                password_confirmation: 'NewPassword123!'
              }
            },
            headers: { 'Accept' => 'application/json' },
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end
  end
end
