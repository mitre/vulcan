# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Token Authentication', type: :request do
  before { Rails.application.reload_routes! }

  let_it_be(:user) { create(:user, admin: true) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }

  let(:token) { create(:personal_access_token, user: user, scopes: %w[read write]) }
  let(:raw_token) { token.raw_token }

  def token_headers(raw = raw_token)
    { 'Authorization' => "Token #{raw}" }
  end

  describe 'token authentication on existing endpoints' do
    it 'authenticates GET requests with a valid read-scoped token' do
      read_token = create(:personal_access_token, user: user, scopes: %w[read])

      get '/srgs', headers: token_headers(read_token.raw_token).merge('Accept' => 'application/json')
      expect(response).to have_http_status(:ok)
    end

    it 'rejects requests with an invalid token' do
      get '/srgs', headers: token_headers('vulcan_bogus_token').merge('Accept' => 'application/json')
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects requests with a revoked token' do
      revoked = create(:personal_access_token, user: user, scopes: %w[read])
      raw = revoked.raw_token
      revoked.revoke!

      get '/srgs', headers: token_headers(raw).merge('Accept' => 'application/json')
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects requests with an expired token' do
      expired = create(:personal_access_token, user: user, scopes: %w[read],
                                               expires_at: 1.day.ago.to_date)
      get '/srgs', headers: token_headers(expired.raw_token).merge('Accept' => 'application/json')
      expect(response).to have_http_status(:unauthorized)
    end

    it 'falls back to Devise session auth when no Authorization header' do
      sign_in user
      get '/srgs', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
    end

    it 'redirects to login when neither token nor session is present' do
      get '/srgs'
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'scope enforcement' do
    it 'allows GET with read scope' do
      read_only = create(:personal_access_token, user: user, scopes: %w[read])
      get '/srgs', headers: token_headers(read_only.raw_token).merge('Accept' => 'application/json')
      expect(response).to have_http_status(:ok)
    end

    it 'rejects POST with read-only scope' do
      read_only = create(:personal_access_token, user: user, scopes: %w[read])
      post '/stigs', headers: token_headers(read_only.raw_token).merge('Accept' => 'application/json'),
                     params: { file: '' }
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows POST with write scope' do
      write_token = create(:personal_access_token, user: user, scopes: %w[write])
      # POST to an endpoint that will process (may fail on params, but should not be 401/403)
      post '/projects', headers: token_headers(write_token.raw_token)
        .merge('Accept' => 'application/json', 'Content-Type' => 'application/json'),
                        params: { project: { name: 'Token Test Project' } }.to_json
      # Accept any non-auth-failure status (the endpoint may return 422 for missing params, but NOT 401/403)
      expect(response.status).not_to eq(401)
      expect(response.status).not_to eq(403)
    end

    it 'allows everything with admin scope' do
      admin_token = create(:personal_access_token, user: user, scopes: %w[admin])
      get '/srgs', headers: token_headers(admin_token.raw_token).merge('Accept' => 'application/json')
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'IP allowlist enforcement' do
    it 'allows request from allowed IP' do
      ip_token = create(:personal_access_token, user: user, scopes: %w[read],
                                                allowed_ips: ['127.0.0.0/8'])

      get '/srgs', headers: token_headers(ip_token.raw_token).merge('Accept' => 'application/json')
      expect(response).to have_http_status(:ok)
    end

    it 'rejects request from disallowed IP' do
      ip_token = create(:personal_access_token, user: user, scopes: %w[read],
                                                allowed_ips: ['10.0.0.0/8'])

      get '/srgs', headers: token_headers(ip_token.raw_token).merge('Accept' => 'application/json')
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to include('IP')
    end
  end

  describe 'CSRF bypass for token auth' do
    it 'allows POST without CSRF token when using API token' do
      write_token = create(:personal_access_token, user: user, scopes: %w[write])

      post '/projects', headers: token_headers(write_token.raw_token)
        .merge('Accept' => 'application/json', 'Content-Type' => 'application/json'),
                        params: { project: { name: 'No CSRF Project' } }.to_json

      # Should NOT get 422 ActionController::InvalidAuthenticityToken
      expect(response.status).not_to eq(422)
    end
  end

  describe 'last_used_at tracking' do
    it 'updates last_used_at on successful token auth' do
      read_token = create(:personal_access_token, user: user, scopes: %w[read])
      expect(read_token.last_used_at).to be_nil

      get '/srgs', headers: token_headers(read_token.raw_token).merge('Accept' => 'application/json')
      expect(response).to have_http_status(:ok)

      read_token.reload
      expect(read_token.last_used_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe 'feature toggle' do
    it 'ignores token header and falls back to Devise when api_tokens.enabled is false' do
      allow(Settings).to receive_message_chain(:api_tokens, :enabled).and_return(false)

      get '/srgs', headers: token_headers
      # Token auth disabled — falls back to Devise which redirects to login
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
