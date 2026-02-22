# frozen_string_literal: true

# Rate limiting configuration using rack-attack.
# Protects against brute-force login attempts and upload abuse.
#
# Uses Rails.cache as the backing store (default: MemoryStore in dev, configurable in production).

module Rack
  # Rate limiting rules for login and upload endpoints.
  class Attack
    ### Throttle login attempts ###
    # 5 attempts per 60 seconds per IP address
    throttle('logins/ip', limit: 5, period: 60.seconds) do |req|
      req.ip if req.path == '/users/sign_in' && req.post?
    end

    # 5 attempts per 60 seconds per email (prevents credential stuffing across IPs)
    throttle('logins/email', limit: 5, period: 60.seconds) do |req|
      if req.path == '/users/sign_in' && req.post?
        # Normalize email to prevent bypass via case/whitespace
        req.params.dig('user', 'email')&.strip&.downcase
      end
    end

    ### Throttle file uploads ###
    # 10 uploads per 60 seconds per user session (generous for batch operations)
    throttle('uploads/ip', limit: 10, period: 60.seconds) do |req|
      upload_paths = %w[/stigs /srgs]
      backup_paths = req.path.match?(%r{/projects/\d+/(import_backup|components)}) ||
                     req.path == '/projects/create_from_backup'

      req.ip if req.post? && (upload_paths.include?(req.path) || backup_paths)
    end

    ### Custom throttle response ###
    self.throttled_responder = lambda do |_req|
      [
        429,
        { 'Content-Type' => 'application/json' },
        [{ toast: { title: 'Rate limited', message: 'Too many requests. Please wait and try again.',
                    variant: 'danger' } }.to_json]
      ]
    end
  end
end
