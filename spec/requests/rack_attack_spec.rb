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
    # Clear rack-attack cache between tests
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
  end

  describe 'login throttling' do
    it 'allows 5 login attempts then returns 429' do
      5.times do |i|
        post '/users/sign_in',
             params: { user: { email: "test#{i}@example.com", password: 'wrong' } },
             headers: { 'REMOTE_ADDR' => '1.2.3.4' }
        expect(response.status).not_to eq(429), "Request #{i + 1} was throttled unexpectedly"
      end

      # 6th attempt should be throttled
      post '/users/sign_in',
           params: { user: { email: 'test@example.com', password: 'wrong' } },
           headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Rate limited')
    end

    it 'throttles by email independently of IP' do
      5.times do |i|
        post '/users/sign_in',
             params: { user: { email: 'target@example.com', password: 'wrong' } },
             headers: { 'REMOTE_ADDR' => "10.0.0.#{i + 1}" }
      end

      # 6th attempt with same email from different IP should be throttled
      post '/users/sign_in',
           params: { user: { email: 'target@example.com', password: 'wrong' } },
           headers: { 'REMOTE_ADDR' => '10.0.0.99' }
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
