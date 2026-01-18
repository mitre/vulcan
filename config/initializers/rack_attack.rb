# frozen_string_literal: true

# Rate limiting and abuse prevention with Rack::Attack
# Documentation: https://github.com/rack/rack-attack

module Rack
  class Attack
    ### Configure Cache ###
    # Use Rails cache for storing request counts
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    ### Throttle Login Attempts ###

    # Limit login attempts by email to 5 requests per 20 seconds
    throttle('limit logins per email', limit: 5, period: 20.seconds) do |req|
      if req.path == '/users/sign_in' && req.post?
        # Normalize email to prevent case-based bypass
        req.params['user']&.[]('email')&.downcase
      end
    end

    # Limit login attempts by IP to 20 requests per 60 seconds
    throttle('limit logins per IP', limit: 20, period: 60.seconds) do |req|
      req.ip if req.path == '/users/sign_in' && req.post?
    end

    ### Throttle Registration ###

    # Limit registrations to 3 per IP per hour
    throttle('limit registrations per IP', limit: 3, period: 1.hour) do |req|
      req.ip if req.path == '/users' && req.post?
    end

    ### Throttle API Requests ###

    # General API rate limit: 300 requests per 5 minutes per IP
    throttle('req/ip', limit: 300, period: 5.minutes, &:ip)

    ### Safelist ###

    # Allow requests from localhost (except in test environment for testing rate limits)
    safelist('allow localhost') do |req|
      ['127.0.0.1', '::1'].include?(req.ip) unless Rails.env.test?
    end

    # Allow health check endpoints
    safelist('allow health checks') do |req|
      req.path.start_with?('/up', '/health_check', '/status')
    end

    ### Custom Response for Throttled Requests ###

    self.throttled_responder = lambda do |request|
      match_data = request.env['rack.attack.match_data']
      now = match_data[:epoch_time]

      headers = {
        'RateLimit-Limit' => match_data[:limit].to_s,
        'RateLimit-Remaining' => '0',
        'RateLimit-Reset' => (now + (match_data[:period] - (now % match_data[:period]))).to_s,
        'Content-Type' => 'application/json'
      }

      [429, headers, [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]]
    end
  end
end

# NOTE: Middleware is enabled in config/application.rb
