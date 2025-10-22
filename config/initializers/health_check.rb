# frozen_string_literal: true

# Health check configuration for Kubernetes probes and monitoring
# Provides /health_check endpoints with comprehensive checks

HealthCheck.setup do |config|
  # Standard checks: database and migrations
  config.standard_checks = %w[database migrations]

  # Custom check for LDAP connectivity (if enabled)
  config.add_custom_check('ldap') do
    if Settings.ldap&.enabled
      begin
        # Simple LDAP bind test
        Net::LDAP.new(host: Settings.ldap.host, port: Settings.ldap.port).bind
        ''
      rescue StandardError => e
        "LDAP connection failed: #{e.message}"
      end
    else
      '' # Skip check if LDAP not enabled
    end
  end

  # Custom check for OIDC connectivity (if enabled)
  config.add_custom_check('oidc') do
    if Settings.oidc&.enabled
      begin
        uri = URI.parse(Settings.oidc.args.issuer)
        response = Net::HTTP.get_response(uri)
        response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection) ? '' : "OIDC issuer returned #{response.code}"
      rescue StandardError => e
        "OIDC connection failed: #{e.message}"
      end
    else
      '' # Skip check if OIDC not enabled
    end
  end

  # Don't include error details in response (security)
  config.include_error_in_response_body = false

  # Suppress health check from logs (reduces noise from frequent K8s probes)
  config.log_level = nil

  # Cache health check responses for 30 seconds to reduce DB load
  config.max_age = 30

  # Success/failure messages
  config.success = 'ok'
  config.failure = 'service unavailable'
end
