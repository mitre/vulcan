# frozen_string_literal: true

# Rate limiting configuration using rack-attack.
# Protects against brute-force login attempts and upload abuse.
#
# Uses Rails.cache as the backing store (default: MemoryStore in dev, configurable in production).

module Rack
  # Rate limiting rules for login and upload endpoints.
  class Attack
    ### Throttle login attempts ###
    # Both the HTML sign-in form and the JSON SPA endpoint are credential
    # oracles and must meter identically — otherwise /api/auth/login is an
    # unthrottled brute-force surface. One shared matcher covers both paths.
    LOGIN_PATHS = ['/users/sign_in', '/api/auth/login'].freeze

    # The email discriminator (prevents credential stuffing across IPs). The
    # HTML form nests it under user[email]; the JSON endpoint sends a
    # top-level email. rack-attack runs before Rails parses a JSON body, so
    # for the JSON path we read and rewind the body ourselves — same
    # technique as the comment throttle below.
    login_email = lambda do |req|
      next nil unless req.post? && LOGIN_PATHS.include?(req.path)

      raw =
        if req.path == '/api/auth/login'
          if req.media_type.to_s.match?(%r{application/json}i)
            begin
              body = JSON.parse(req.body.read)
              req.body.rewind
              body['email']
            rescue JSON::ParserError
              req.body.rewind
              nil
            end
          else
            req.params['email']
          end
        else
          req.params.dig('user', 'email')
        end
      # Normalize email to prevent bypass via case/whitespace
      raw&.strip&.downcase
    end

    # 5 attempts per 60 seconds per IP address
    throttle('logins/ip', limit: 5, period: 60.seconds) do |req|
      req.ip if req.post? && LOGIN_PATHS.include?(req.path)
    end

    # 5 attempts per 60 seconds per email (prevents credential stuffing across IPs)
    throttle('logins/email', limit: 5, period: 60.seconds, &login_email)

    ### Throttle file uploads ###
    # 10 uploads per 60 seconds per user session (generous for batch operations)
    throttle('uploads/ip', limit: 10, period: 60.seconds) do |req|
      upload_paths = %w[/stigs /srgs]
      backup_paths = req.path.match?(%r{/projects/\d+/(import_backup|components)}) ||
                     req.path == '/projects/create_from_backup'

      req.ip if req.post? && (upload_paths.include?(req.path) || backup_paths)
    end

    ### Throttle comment posts ###
    # External commenters (industry users on the Container SRG project) are
    # the abuse surface for the new viewer-can-comment workflow. A
    # compromised viewer credential could spam the triage queue and the
    # audit log. We throttle the comment-only path; other review actions
    # (request_review, approve, etc.) are not affected by these throttles.
    #
    # Discriminator: authenticated user id (Devise/Warden), falling back to
    # IP for anonymous edge cases (which the controller will reject anyway).
    comment_post_user = lambda do |req|
      next nil unless req.path.match?(%r{\A/rules/\d+/reviews\z}) && req.post?
      next nil unless req.media_type.to_s.match?(%r{application/json}i)

      begin
        body = JSON.parse(req.body.read)
        req.body.rewind
        next nil unless body.dig('review', 'action') == 'comment'
      rescue JSON::ParserError
        req.body.rewind
        next nil
      end

      user = req.env['warden']&.user
      user ? user.id.to_s : req.ip
    end

    throttle('comments/user/minute', limit: 10, period: 60.seconds, &comment_post_user)
    throttle('comments/user/hour',   limit: 100, period: 1.hour,    &comment_post_user)

    ### Throttle reaction endpoints ###
    # POST = toggle (cheap action, but high-volume signal); GET = lazy
    # hover-fetch of reactor names (per-comment, can fan out across a
    # long thread). Discriminator falls back to req.ip when the user is
    # unauthenticated so anonymous traffic still meters.
    reactions_user = lambda do |req|
      next nil unless req.path.match?(%r{\A/reviews/\d+/reactions\z})

      user = req.env['warden']&.user
      user ? user.id.to_s : req.ip
    end

    throttle('reactions_post/user', limit: 60, period: 60.seconds) do |req|
      reactions_user.call(req) if req.post?
    end

    throttle('reactions_get/user', limit: 300, period: 60.seconds) do |req|
      reactions_user.call(req) if req.get?
    end

    ### Throttle API token requests ###
    throttle('api_token/ip', limit: 300, period: 60.seconds) do |req|
      req.ip if req.env['HTTP_AUTHORIZATION']&.start_with?('Token ')
    end

    ### Custom throttle response ###
    self.throttled_responder = lambda do |_req|
      [
        429,
        { 'Content-Type' => 'application/json' },
        [{ toast: { title: 'Rate limited', message: ['Too many requests. Please wait and try again.'],
                    variant: 'danger' } }.to_json]
      ]
    end
  end
end
