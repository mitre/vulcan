# frozen_string_literal: true

# Helper module for OIDC discovery document fetching and validation
# Provides caching, security validation, and error handling for OpenID Connect discovery
# rubocop:disable Metrics/ModuleLength
# This module is intentionally long as it handles the complete OIDC discovery workflow:
# fetching, caching, validation, error handling, and logging
module OidcDiscoveryHelper
  extend ActiveSupport::Concern

  HTTPS_PROTOCOL = 'https://'

  private

  def fetch_oidc_discovery_document(issuer_url, cache_key = 'oidc_discovery')
    # Validate and normalize issuer URL first
    normalized_issuer = normalize_issuer_url(issuer_url)

    # Check for cached result with issuer validation
    cached = get_cached_discovery(cache_key, normalized_issuer)
    return cached if cached

    # Prevent concurrent requests for the same discovery URL
    discovery_url = "#{normalized_issuer}/.well-known/openid-configuration"
    request_lock_key = "oidc_discovery:lock:#{normalized_issuer}"

    # Check if a request is already in progress
    if Rails.cache.read(request_lock_key)
      log_oidc_discovery_event('concurrent_request_blocked', normalized_issuer, {
                                 reason: 'request_in_progress',
                                 cache_key: cache_key
                               })
      return nil
    end

    # Mark request in progress with short TTL
    Rails.cache.write(request_lock_key, true, expires_in: 10.seconds)

    begin
      # Perform HTTP request with timeout and security constraints
      config = fetch_discovery_with_security(discovery_url)

      if config
        # Validate discovery document against OIDC spec and security requirements
        validate_discovery_document(config, normalized_issuer)

        # Cache with expiration and metadata
        cache_discovery_document(config, cache_key, normalized_issuer)

        log_oidc_discovery_event('success', normalized_issuer, {
                                   endpoints_discovered: count_discovered_endpoints(config),
                                   cache_duration: '1 hour',
                                   response_time_ms: nil # Could be added with timing
                                 })
        config
      else
        log_oidc_discovery_event('fetch_failed', normalized_issuer, {
                                   reason: 'empty_response',
                                   url: discovery_url
                                 })
        nil
      end
    rescue SecurityError => e
      log_oidc_discovery_event('security_error', normalized_issuer, {
                                 error: e.message,
                                 url: discovery_url
                               })
      nil
    rescue JSON::ParserError => e
      log_oidc_discovery_event('parse_error', normalized_issuer, {
                                 error: 'Invalid JSON response',
                                 details: e.message,
                                 url: discovery_url
                               })
      nil
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      log_oidc_discovery_event('timeout', normalized_issuer, {
                                 error: e.class.name,
                                 details: e.message,
                                 url: discovery_url
                               })
      nil
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      log_oidc_discovery_event('network_error', normalized_issuer, {
                                 error: e.class.name,
                                 details: e.message,
                                 url: discovery_url
                               })
      nil
    rescue Net::HTTPError, URI::InvalidURIError => e
      log_oidc_discovery_event('unexpected_error', normalized_issuer, {
                                 error: e.class.name,
                                 details: e.message,
                                 url: discovery_url,
                                 backtrace: Rails.env.development? ? e.backtrace.first(5) : nil
                               })
      nil
    ensure
      # Clear the request lock from cache
      request_lock_key = "oidc_discovery:lock:#{normalized_issuer}"
      Rails.cache.delete(request_lock_key)
    end
  end

  def normalize_issuer_url(issuer_url)
    # Ensure HTTPS for security
    normalized = issuer_url.to_s.chomp('/')

    # Security: Only allow HTTPS in production
    raise SecurityError, 'OIDC issuer must use HTTPS in production environment' unless Rails.env.development? || normalized.start_with?(HTTPS_PROTOCOL)

    # Validate URL format
    uri = URI.parse(normalized)
    raise ArgumentError, "Invalid issuer URL format: #{normalized}" unless uri.scheme && uri.host

    normalized
  end

  def fetch_discovery_with_security(discovery_url)
    uri = URI(discovery_url)

    # Configure HTTP client with timeouts and security settings
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
    http.open_timeout = 5  # 5 second connection timeout
    http.read_timeout = 10 # 10 second read timeout

    # Create request with security headers
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = "Vulcan/#{begin
      Rails.application.class.module_parent.const_get(:VERSION)
    rescue StandardError
      'unknown'
    end}"
    request['Accept'] = 'application/json'

    # Perform request
    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      # Validate response size (prevent DoS)
      raise SecurityError, "Discovery document too large: #{response.body.length} bytes" if response.body.length > 100_000 # 100KB limit

      JSON.parse(response.body)
    else
      Rails.logger.warn "OIDC Discovery failed: HTTP #{response.code} #{response.message} for #{discovery_url}"
      nil
    end
  end

  def get_cached_discovery(cache_key, expected_issuer)
    # Use Rails.cache instead of session to avoid cookie overflow
    full_cache_key = "oidc_discovery:#{cache_key}:#{expected_issuer}"
    cached = Rails.cache.read(full_cache_key)
    return nil unless cached

    # Validate cached issuer matches current request (handle issuer URL changes)
    cached_issuer = cached['issuer']
    if cached_issuer != expected_issuer
      log_oidc_discovery_event('cache_invalidated', expected_issuer, {
                                 reason: 'issuer_mismatch',
                                 cached_issuer: cached_issuer,
                                 expected_issuer: expected_issuer
                               })
      Rails.cache.delete(full_cache_key)
      return nil
    end

    # Validate cache version for forward compatibility
    cache_version = cached['vulcan_cache_version']
    if cache_version != '1.1'
      log_oidc_discovery_event('cache_invalidated', expected_issuer, {
                                 reason: 'version_mismatch',
                                 cached_version: cache_version,
                                 expected_version: '1.1'
                               })
      Rails.cache.delete(full_cache_key)
      return nil
    end

    log_oidc_discovery_event('cache_hit', expected_issuer, {
                               cached_at: cached['cached_at'],
                               expires_at: cached['expires_at']
                             })
    cached
  end

  def cache_discovery_document(config, cache_key, normalized_issuer)
    # Add enhanced caching metadata
    config['expires_at'] = 1.hour.from_now
    config['cached_at'] = Time.current
    config['vulcan_cache_version'] = '1.1'
    config['cached_issuer'] = normalized_issuer
    config['cache_key'] = cache_key

    # Use Rails.cache instead of session to avoid cookie overflow
    full_cache_key = "oidc_discovery:#{cache_key}:#{normalized_issuer}"
    Rails.cache.write(full_cache_key, config, expires_in: 1.hour)
    Rails.logger.debug { "Cached OIDC discovery for #{normalized_issuer}, expires in 1 hour" }
  end

  # rubocop:disable Naming/PredicateMethod
  def validate_discovery_document(config, expected_issuer)
    # Security: Validate issuer matches expected value (prevents man-in-the-middle attacks)
    actual_issuer = config['issuer']
    raise SecurityError, "OIDC Discovery: Issuer mismatch. Expected '#{expected_issuer}', got '#{actual_issuer}'" unless actual_issuer == expected_issuer

    # Security: Ensure issuer uses HTTPS in production
    raise SecurityError, 'OIDC Discovery: Issuer must use HTTPS in production' unless Rails.env.development? || actual_issuer.start_with?(HTTPS_PROTOCOL)

    # OIDC Core spec 1.0: Required discovery metadata fields
    required_fields = %w[
      issuer
      authorization_endpoint
      response_types_supported
      subject_types_supported
      id_token_signing_alg_values_supported
    ]

    missing_required_fields = required_fields - config.keys
    raise ArgumentError, "OIDC Discovery: Missing required fields: #{missing_required_fields.join(', ')}" if missing_required_fields.any?

    # Handle partial discovery documents: warn about missing optional but important fields
    recommended_fields = %w[
      token_endpoint
      userinfo_endpoint
      jwks_uri
      end_session_endpoint
      revocation_endpoint
      introspection_endpoint
    ]

    missing_recommended_fields = recommended_fields - config.keys
    if missing_recommended_fields.any?
      Rails.logger.warn "OIDC Discovery: Missing recommended fields for #{actual_issuer}: " \
                        "#{missing_recommended_fields.join(', ')}. Some functionality may be limited."
    end

    # Schema forward compatibility: Log unknown fields for debugging
    # These are official OIDC specification field names that cannot be shortened
    known_fields = %w[
      issuer authorization_endpoint token_endpoint userinfo_endpoint jwks_uri
      registration_endpoint scopes_supported response_types_supported response_modes_supported
      grant_types_supported acr_values_supported subject_types_supported id_token_signing_alg_values_supported
      id_token_encryption_alg_values_supported id_token_encryption_enc_values_supported userinfo_signing_alg_values_supported
      userinfo_encryption_alg_values_supported request_object_signing_alg_values_supported request_object_encryption_alg_values_supported
      token_endpoint_auth_methods_supported token_endpoint_auth_signing_alg_values_supported display_values_supported
      claim_types_supported claims_supported service_documentation claims_locales_supported ui_locales_supported
      claims_parameter_supported request_parameter_supported request_uri_parameter_supported require_request_uri_registration
      op_policy_uri op_tos_uri revocation_endpoint revocation_endpoint_auth_methods_supported revocation_endpoint_auth_signing_alg_values_supported
      introspection_endpoint introspection_endpoint_auth_methods_supported introspection_endpoint_auth_signing_alg_values_supported
      code_challenge_methods_supported end_session_endpoint check_session_iframe frontchannel_logout_supported frontchannel_logout_session_supported
      backchannel_logout_supported backchannel_logout_session_supported
    ]
    unknown_fields = config.keys - known_fields - %w[expires_at cached_at vulcan_cache_version cached_issuer
                                                     cache_key]
    if unknown_fields.any?
      Rails.logger.debug do
        "OIDC Discovery: Unknown fields in discovery document for #{actual_issuer}: " \
          "#{unknown_fields.join(', ')}. These may be provider-specific extensions."
      end
    end

    # Validate endpoint URLs are HTTPS in production
    endpoint_fields = %w[authorization_endpoint token_endpoint userinfo_endpoint end_session_endpoint jwks_uri]
    endpoint_fields.each do |field|
      endpoint_url = config[field]
      next if endpoint_url.blank?

      raise SecurityError, "OIDC Discovery: #{field} must use HTTPS in production: #{endpoint_url}" unless Rails.env.development? || endpoint_url.start_with?(HTTPS_PROTOCOL)
    end

    # Validate response_types_supported contains 'code' for authorization code flow
    response_types = config['response_types_supported']
    Rails.logger.warn "OIDC Discovery: 'code' response type not supported, may affect authentication flow" unless response_types.is_a?(Array) && response_types.include?('code')

    # Validate signing algorithms include RS256 (most common and secure)
    signing_algs = config['id_token_signing_alg_values_supported']
    Rails.logger.warn 'OIDC Discovery: RS256 signing algorithm not supported, may affect token validation' unless signing_algs.is_a?(Array) && signing_algs.include?('RS256')

    # Log provider capabilities for debugging
    Rails.logger.debug do
      "OIDC Discovery validation passed for #{actual_issuer}:\n  " \
        "- Response types: #{response_types&.join(', ')}\n  " \
        "- Signing algorithms: #{signing_algs&.join(', ')}\n  " \
        "- Token endpoint: #{config['token_endpoint'].present? ? 'present' : 'missing'}\n  " \
        "- Userinfo endpoint: #{config['userinfo_endpoint'].present? ? 'present' : 'missing'}\n  " \
        "- End session endpoint: #{config['end_session_endpoint'].present? ? 'present' : 'missing'}"
    end

    true
  end
  # rubocop:enable Naming/PredicateMethod

  def fetch_oidc_endpoint(endpoint_name, fallback_url = nil)
    return fallback_url unless Settings.oidc.discovery

    issuer_url = Settings.oidc.args.issuer || ENV.fetch('VULCAN_OIDC_ISSUER_URL', nil)
    return fallback_url unless issuer_url

    discovery = fetch_oidc_discovery_document(issuer_url)
    discovery&.[](endpoint_name) || fallback_url
  end

  # Structured logging for OIDC discovery events
  # Ensures container visibility in ECS, Docker, Kubernetes deployments
  def log_oidc_discovery_event(event_type, issuer, details = {})
    log_data = {
      oidc_discovery_event: event_type,
      issuer: issuer,
      timestamp: Time.current.utc.iso8601
    }.merge(details)

    # Use structured logging if available, otherwise readable format
    if ENV['STRUCTURED_LOGGING'].present?
      Rails.logger.info log_data.to_json
    else
      message = "OIDC Discovery [#{event_type.upcase}] #{issuer}"
      message += " - #{details.map { |k, v| "#{k}=#{v}" }.join(', ')}" if details.any?
      Rails.logger.info message
    end
  end

  # Count discovered endpoints for monitoring and debugging
  def count_discovered_endpoints(discovery_document)
    return 0 unless discovery_document.is_a?(Hash)

    endpoint_fields = %w[
      authorization_endpoint token_endpoint userinfo_endpoint
      end_session_endpoint jwks_uri revocation_endpoint
      introspection_endpoint registration_endpoint
    ]

    endpoint_fields.count { |field| discovery_document[field].present? }
  end
end
# rubocop:enable Metrics/ModuleLength
