# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack Rate Limiting' do
  before(:all) do
    # Set up memory store once for all tests
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  before do
    Rails.application.reload_routes!
    # Clear cache before EACH test for isolation
    Rack::Attack.cache.store.clear
  end

  # Clean up only after ALL tests
  after(:all) do
    Rack::Attack.cache.store.clear
    Rack::Attack.clear_configuration
  end

  describe 'configured throttles' do
    it 'includes expected throttle keys' do
      expect(Rack::Attack.throttles.keys).to include(
        'limit logins per email',
        'limit logins per IP',
        'limit registrations per IP',
        'req/ip'
      )
    end
  end

  describe 'login throttling by email' do
    it 'allows 5 login attempts then blocks the 6th' do
      email = 'test@example.com'

      # First 5 attempts should work (will redirect but not 429)
      5.times do
        post '/users/sign_in', params: { user: { email: email, password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '1.2.3.4' }
        expect(response).not_to have_http_status(:too_many_requests)
      end

      # 6th attempt should be rate limited
      post '/users/sign_in', params: { user: { email: email, password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'is case-insensitive for email addresses' do
      # Mix of cases should all count towards same email
      post '/users/sign_in', params: { user: { email: 'Test@Example.COM', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      post '/users/sign_in', params: { user: { email: 'test@example.com', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      post '/users/sign_in', params: { user: { email: 'TEST@EXAMPLE.COM', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      post '/users/sign_in', params: { user: { email: 'test@example.com', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      post '/users/sign_in', params: { user: { email: 'test@example.com', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '1.2.3.4' }

      # 6th attempt should be blocked
      post '/users/sign_in', params: { user: { email: 'test@example.com', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'login throttling by IP' do
    it 'allows 20 attempts per IP then blocks' do
      ip = '99.99.99.99' # Use unique IP to avoid conflicts

      # 20 attempts with different emails
      20.times do |i|
        post '/users/sign_in', params: { user: { email: "user#{i}@test.com", password: 'wrong' } }, headers: { 'REMOTE_ADDR' => ip }
        expect(response).not_to have_http_status(:too_many_requests)
      end

      # 21st should be blocked
      post '/users/sign_in', params: { user: { email: 'final@test.com', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => ip }
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'different IPs have separate limits' do
      # Exhaust IP 1's limit with unique emails (20 requests to hit IP limit)
      20.times do |i|
        post '/users/sign_in', params: { user: { email: "unique1-#{i}@test.com", password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '192.168.1.1' }
        expect(response.status).not_to eq(429), "Request #{i + 1} was blocked unexpectedly"
      end

      # 21st request from IP 1 should be blocked
      post '/users/sign_in', params: { user: { email: 'unique1-final@test.com', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '192.168.1.1' }
      expect(response).to have_http_status(:too_many_requests)

      # IP 2 should still work (different IP, fresh limit)
      post '/users/sign_in', params: { user: { email: 'unique2-test@test.com', password: 'wrong' } }, headers: { 'REMOTE_ADDR' => '192.168.2.2' }
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  describe 'health check safelist' do
    it 'allows unlimited /up requests' do
      # Make many requests
      100.times do
        get '/up', headers: { 'REMOTE_ADDR' => '88.88.88.88' }
        expect(response).to have_http_status(:ok)
      end
    end

    it 'allows unlimited /status requests' do
      50.times do
        get '/status', headers: { 'REMOTE_ADDR' => '88.88.88.88' }
        expect(response).to have_http_status(:ok)
      end
    end

    it 'allows unlimited /health_check requests' do
      50.times do
        get '/health_check', headers: { 'REMOTE_ADDR' => '88.88.88.88' }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'general API throttling' do
    it 'tracks request count' do
      ip = '77.77.77.77'
      get '/projects', headers: { 'REMOTE_ADDR' => ip }

      # Check that it's tracking
      expect(request.env['rack.attack.throttle_data']).to be_present
      expect(request.env['rack.attack.throttle_data']['req/ip'][:count]).to eq(1)
    end
  end
end
