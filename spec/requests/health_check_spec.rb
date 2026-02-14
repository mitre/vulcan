# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health Check Endpoints' do
  before do
    Rails.application.reload_routes!
  end

  describe 'GET /up (liveness probe)' do
    it 'returns success without authentication' do
      get '/up'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /health_check (readiness probe)' do
    it 'returns ok when database is connected' do
      get '/health_check'
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('ok')
    end
  end

  describe 'GET /health_check/database' do
    it 'returns ok when database is connected' do
      get '/health_check/database'
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('ok')
    end
  end
end
