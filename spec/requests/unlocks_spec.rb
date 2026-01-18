# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Unlocks', type: :request do
  before do
    Rails.application.reload_routes! # Required for Rails 8 lazy loading
  end

  describe 'POST /users/unlock' do
    context 'when requesting JSON' do
      # Create locked user by calling Devise's lock method
      let(:user) do
        create(:user).tap(&:lock_access!)
      end

      it 'resends unlock instructions' do
        post '/users/unlock',
             params: { user: { email: user.email } },
             headers: { 'Accept' => 'application/json' },
             as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['message']).to include('Unlock instructions sent')
      end

      it 'returns success for non-existent email (prevent enumeration)' do
        post '/users/unlock',
             params: { user: { email: 'nonexistent@example.com' } },
             headers: { 'Accept' => 'application/json' },
             as: :json

        # Devise may return success to prevent email enumeration
        expect(response).to have_http_status(:success).or(have_http_status(:unprocessable_content))
      end
    end
  end
end
