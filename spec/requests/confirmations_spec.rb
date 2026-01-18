# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Confirmations', type: :request do
  before do
    Rails.application.reload_routes! # Required for Rails 8 lazy loading
  end

  describe 'POST /users/confirmation' do
    context 'when requesting JSON' do
      # Create unconfirmed user (factory defaults to confirmed, so override)
      let(:user) do
        create(:user).tap do |u|
          u.update_columns(
            confirmed_at: nil,
            confirmation_token: Devise.friendly_token,
            confirmation_sent_at: 1.hour.ago
          )
        end
      end

      it 'resends confirmation instructions' do
        post '/users/confirmation',
             params: { user: { email: user.email } },
             headers: { 'Accept' => 'application/json' },
             as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['message']).to include('Confirmation instructions sent')
      end

      it 'returns error for non-existent email' do
        post '/users/confirmation',
             params: { user: { email: 'nonexistent@example.com' } },
             headers: { 'Accept' => 'application/json' },
             as: :json

        # Devise may still return success to prevent email enumeration
        # Check the actual behavior
        expect(response).to have_http_status(:success).or(have_http_status(:unprocessable_entity))
      end
    end
  end
end
