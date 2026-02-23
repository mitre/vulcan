# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
# - Login attempts are throttled to 5 per 60 seconds per IP
# - Login attempts are throttled to 5 per 60 seconds per email
# - File uploads are throttled to 10 per 60 seconds per IP
# - Throttled responses return 429 with a JSON error message

RSpec.describe 'Rack::Attack throttling' do
  before do
    Rails.application.reload_routes!
    # Create a fresh, isolated cache store for each test to prevent
    # cross-contamination from other specs in the same parallel worker
    @fresh_store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store = @fresh_store
    Rack::Attack.reset!
  end

  after do
    # Restore default cache and clear to prevent bleeding into other tests
    Rack::Attack.cache.store = Rails.cache
    Rack::Attack.reset!
  end

  describe 'login throttling' do
    it 'allows 5 login attempts then returns 429' do
      # Use unique IP per test run to avoid cross-test contamination
      test_ip = "192.168.#{rand(1..254)}.#{rand(1..254)}"

      5.times do |i|
        post '/users/sign_in',
             params: { user: { email: "throttle-ip-#{i}-#{SecureRandom.hex(4)}@example.com", password: 'wrong' } },
             headers: { 'REMOTE_ADDR' => test_ip }
        expect(response.status).not_to eq(429), "Request #{i + 1} was throttled unexpectedly"
      end

      # 6th attempt should be throttled
      post '/users/sign_in',
           params: { user: { email: "throttle-ip-final-#{SecureRandom.hex(4)}@example.com", password: 'wrong' } },
           headers: { 'REMOTE_ADDR' => test_ip }
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Rate limited')
    end

    it 'throttles by email independently of IP' do
      # Use unique email per test run to avoid cross-test contamination
      target_email = "throttle-email-#{SecureRandom.hex(6)}@example.com"

      5.times do |i|
        post '/users/sign_in',
             params: { user: { email: target_email, password: 'wrong' } },
             headers: { 'REMOTE_ADDR' => "172.16.#{rand(1..254)}.#{i + 1}" }
      end

      # 6th attempt with same email from different IP should be throttled
      post '/users/sign_in',
           params: { user: { email: target_email, password: 'wrong' } },
           headers: { 'REMOTE_ADDR' => "172.16.#{rand(1..254)}.99" }
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
