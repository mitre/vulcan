# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Settings' do
  before { Rails.application.reload_routes! }

  describe 'GET /api/settings' do
    it 'returns settings without requiring authentication' do
      get '/api/settings', as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'includes banner configuration' do
      get '/api/settings', as: :json

      body = response.parsed_body
      expect(body).to have_key('banner')
      expect(body['banner']).to have_key('enabled')
      expect(body['banner']).to have_key('text')
      expect(body['banner']).to have_key('background_color')
      expect(body['banner']).to have_key('text_color')
    end

    it 'includes consent configuration' do
      get '/api/settings', as: :json

      body = response.parsed_body
      expect(body).to have_key('consent')
      expect(body['consent']).to have_key('enabled')
      expect(body['consent']).to have_key('version')
      expect(body['consent']).to have_key('title')
      expect(body['consent']).to have_key('content')
    end

    it 'includes auth provider flags' do
      get '/api/settings', as: :json

      body = response.parsed_body
      expect(body).to have_key('local_login')
      expect(body['local_login']['enabled']).to be(true).or be(false)
      expect(body).to have_key('ldap')
      expect(body['ldap']['enabled']).to be(true).or be(false)
      expect(body).to have_key('oidc')
      expect(body['oidc']['enabled']).to be(true).or be(false)
    end

    it 'includes registration and SMTP flags' do
      get '/api/settings', as: :json

      body = response.parsed_body
      expect(body['user_registration']['enabled']).to be(true).or be(false)
      expect(body['smtp']['enabled']).to be(true).or be(false)
    end

    it 'includes password policy for client-side validation' do
      get '/api/settings', as: :json

      body = response.parsed_body
      expect(body).to have_key('password')
      expect(body['password']['min_length']).to eq(Settings.password.min_length)
    end

    it 'does NOT leak sensitive settings' do
      get '/api/settings', as: :json

      body = response.parsed_body
      flat = body.to_json
      expect(flat).not_to include('SECRET_KEY_BASE')
      expect(flat).not_to include('bind_dn')
      expect(flat).not_to include('client_secret')
      expect(flat).not_to include('api_token')
      expect(flat).not_to include('smtp_server_password')
      expect(body.dig('smtp', 'settings')).to be_nil
      expect(body.dig('ldap', 'servers')).to be_nil
      expect(body.dig('oidc', 'args')).to be_nil
    end
  end
end
