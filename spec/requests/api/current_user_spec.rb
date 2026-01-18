# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::Auth::Me' do
  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/auth/me' do
    context 'when authenticated' do
      let(:user) { create(:user, email: 'test@example.com', admin: false) }

      before { sign_in user }

      it 'returns user JSON with status 200' do
        get '/api/auth/me'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['user']).to include(
          'id' => user.id,
          'email' => user.email,
          'admin' => false
        )
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        get '/api/auth/me'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
