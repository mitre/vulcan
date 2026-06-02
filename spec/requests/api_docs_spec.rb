# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Docs (Scalar viewer)' do
  let(:user) { create(:user) }

  before { Rails.application.reload_routes! }

  describe 'GET /api/docs' do
    it 'requires authentication' do
      get '/api/docs'
      expect(response).to redirect_to(new_user_session_path)
    end

    context 'when authenticated' do
      before { sign_in user }

      it 'returns 200 with HTML' do
        get '/api/docs'
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/html')
      end

      it 'includes the Scalar CDN script tag' do
        get '/api/docs'
        expect(response.body).to include('cdn.jsdelivr.net/npm/@scalar/api-reference')
      end

      it 'points at the bundled OpenAPI spec' do
        get '/api/docs'
        expect(response.body).to include('openapi.yaml')
      end
    end
  end
end
