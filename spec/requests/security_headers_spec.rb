# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security Headers', type: :request do
  before do
    Rails.application.reload_routes!
  end

  describe 'security headers on public endpoints' do
    it 'includes X-Frame-Options header' do
      get '/up'
      expect(response.headers['X-Frame-Options']).to eq('SAMEORIGIN')
    end

    it 'includes X-Content-Type-Options header' do
      get '/up'
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    end

    it 'includes X-XSS-Protection header' do
      get '/up'
      expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
    end

    it 'includes Referrer-Policy header' do
      get '/up'
      expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
    end

    it 'includes Permissions-Policy header' do
      get '/up'
      expect(response.headers['Permissions-Policy']).to eq('geolocation=(), microphone=(), camera=()')
    end
  end

  describe 'security headers on authenticated endpoints' do
    let(:user) { create(:user) }

    before { sign_in user }

    it 'includes all security headers on authenticated requests' do
      get '/projects'

      expect(response.headers['X-Frame-Options']).to eq('SAMEORIGIN')
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
      expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
      expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
    end
  end
end
