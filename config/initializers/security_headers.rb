# frozen_string_literal: true

# Security headers to protect against common web vulnerabilities
# Based on OWASP recommendations

Rails.application.config.action_dispatch.default_headers.merge!(
  {
    # Prevent clickjacking - only allow framing from same origin
    'X-Frame-Options' => 'SAMEORIGIN',

    # Prevent MIME type sniffing
    'X-Content-Type-Options' => 'nosniff',

    # Enable XSS protection (for older browsers)
    'X-XSS-Protection' => '1; mode=block',

    # Control referrer information
    'Referrer-Policy' => 'strict-origin-when-cross-origin',

    # Permissions policy (formerly Feature-Policy)
    'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()'
  }
)

# Content Security Policy (CSP) - Commented out for now as it requires testing
# Uncomment and customize after testing with your application
#
# Rails.application.config.content_security_policy do |policy|
#   policy.default_src :self, :https
#   policy.font_src    :self, :https, :data
#   policy.img_src     :self, :https, :data
#   policy.object_src  :none
#   policy.script_src  :self, :https
#   policy.style_src   :self, :https, :unsafe_inline
#
#   # Specify URI for violation reports
#   # policy.report_uri "/csp-violation-report-endpoint"
# end
#
# Rails.application.config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
# Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
