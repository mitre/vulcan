# frozen_string_literal: true

# OIDC Configuration Startup Validation
# Validates OIDC configuration at application boot to catch misconfigurations early

Rails.application.config.after_initialize do
  # Run validation whenever OIDC is enabled, regardless of environment
  # This allows developers to test OIDC locally if they have proper configuration

  # Only validate if OIDC is enabled
  next unless Settings.oidc&.enabled

  begin
    OidcStartupValidator.validate_configuration
  rescue StandardError => e
    Rails.logger.error "OIDC Startup Validation Failed: #{e.message}"
    # Don't crash the application on validation failure
    # Log the error and let the app start (graceful degradation)
  end
end

# Validates OIDC configuration at application startup
# Ensures required settings are present and properly formatted
class OidcStartupValidator
  class << self
    def validate_configuration
      Rails.logger.info '🔍 Running OIDC startup configuration validation...'

      # Step 1: Validate required configuration variables
      validate_required_settings

      # Step 2: Validate issuer URL format and accessibility
      validate_issuer_url

      # Step 3: Test discovery endpoint if discovery is enabled
      validate_discovery_endpoint if Settings.oidc.discovery

      # Step 4: Check for deprecated configuration patterns
      warn_deprecated_patterns

      # Step 5: Validate redirect URI format
      validate_redirect_uri

      Rails.logger.info '✅ OIDC configuration validation completed successfully'
    end

    private

    def validate_required_settings
      missing_settings = []

      # Check essential OIDC settings
      missing_settings << 'VULCAN_OIDC_ISSUER_URL' if issuer_url.blank?
      missing_settings << 'VULCAN_OIDC_CLIENT_ID' if client_id.blank?
      missing_settings << 'VULCAN_OIDC_CLIENT_SECRET' if client_secret.blank?

      if missing_settings.any?
        raise ArgumentError, "Missing required OIDC configuration: #{missing_settings.join(', ')}"
      end

      Rails.logger.debug '✓ Required OIDC settings present'
    end

    def validate_issuer_url
      url = issuer_url

      begin
        uri = URI.parse(url)

        # Validate URL has host
        raise ArgumentError, "OIDC issuer URL missing hostname: #{url}" if uri.host.blank?

        # Validate URL scheme
        if uri.scheme&.downcase != 'https'
          raise ArgumentError, "OIDC issuer must use HTTPS in production: #{url}" if Rails.env.production?

          Rails.logger.warn "⚠️  OIDC issuer using HTTP in #{Rails.env}: #{url}"
        end

        # Test basic connectivity (with timeout)
        test_issuer_connectivity(uri) if should_test_connectivity?

        Rails.logger.debug { "✓ OIDC issuer URL format valid: #{url}" }
      rescue URI::InvalidURIError => e
        raise ArgumentError, "Invalid OIDC issuer URL format: #{url} - #{e.message}"
      end
    end

    def validate_discovery_endpoint
      return unless Settings.oidc.discovery

      # Skip discovery endpoint testing in test environment when WebMock is active
      # This allows unit tests to run without making real HTTP requests
      return if Rails.env.test? && defined?(WebMock)

      discovery_url = "#{issuer_url.chomp('/')}/.well-known/openid-configuration"

      begin
        Rails.logger.debug { "Testing OIDC discovery endpoint: #{discovery_url}" }

        uri = URI(discovery_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
        http.open_timeout = 10 # Longer timeout for startup validation
        http.read_timeout = 15

        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] =
          "Vulcan-Startup-Validation/#{begin
            Rails.application.class.module_parent.const_get(:VERSION)
          rescue StandardError
            'unknown'
          end}"
        request['Accept'] = 'application/json'

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          # Parse and validate discovery document structure
          discovery = JSON.parse(response.body)
          validate_discovery_document_structure(discovery)

          Rails.logger.info '✅ OIDC discovery endpoint accessible and valid'
          log_discovered_capabilities(discovery)
        else
          Rails.logger.warn "⚠️  OIDC discovery endpoint returned HTTP #{response.code}: #{discovery_url}"
          Rails.logger.warn '    OIDC will fall back to manual configuration if needed'
        end
      rescue JSON::ParserError => e
        Rails.logger.warn "⚠️  OIDC discovery endpoint returned invalid JSON: #{e.message}"
        Rails.logger.warn '    OIDC will fall back to manual configuration if needed'
      rescue Net::OpenTimeout, Net::ReadTimeout
        Rails.logger.warn "⚠️  OIDC discovery endpoint timeout: #{discovery_url}"
        Rails.logger.warn '    OIDC will fall back to manual configuration if needed'
      rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
        Rails.logger.warn "⚠️  OIDC discovery endpoint network error: #{e.message}"
        Rails.logger.warn '    OIDC will fall back to manual configuration if needed'
      rescue StandardError => e
        Rails.logger.warn "⚠️  OIDC discovery endpoint validation failed: #{e.message}"
        Rails.logger.warn '    OIDC will fall back to manual configuration if needed'
      end
    end

    def validate_discovery_document_structure(discovery)
      # Check required OIDC Core fields
      required_fields = %w[
        issuer
        authorization_endpoint
        response_types_supported
        subject_types_supported
        id_token_signing_alg_values_supported
      ]

      missing_fields = required_fields - discovery.keys
      if missing_fields.any?
        Rails.logger.warn "⚠️  OIDC discovery document missing required fields: #{missing_fields.join(', ')}"
      end

      # Validate issuer matches configured issuer
      actual_issuer = discovery['issuer']
      expected_issuer = issuer_url

      return if actual_issuer == expected_issuer

      Rails.logger.warn '⚠️  OIDC discovery issuer mismatch:'
      Rails.logger.warn "    Expected: #{expected_issuer}"
      Rails.logger.warn "    Actual: #{actual_issuer}"
    end

    def warn_deprecated_patterns
      warnings = []

      # Check for deprecated manual endpoint configuration when discovery is enabled
      if Settings.oidc.discovery
        manual_endpoints = [
          ENV['VULCAN_OIDC_AUTHORIZATION_URL'],
          ENV['VULCAN_OIDC_TOKEN_URL'],
          ENV['VULCAN_OIDC_USERINFO_URL'],
          ENV['VULCAN_OIDC_JWKS_URI']
        ].compact

        if manual_endpoints.any?
          warnings << 'Manual OIDC endpoints configured while discovery is enabled (these will be used as fallbacks)'
        end
      end

      # Check for old-style configuration variables
      deprecated_vars = {
        'VULCAN_OIDC_HOST' => 'Use VULCAN_OIDC_ISSUER_URL instead',
        'VULCAN_OIDC_PORT' => 'Use VULCAN_OIDC_ISSUER_URL instead',
        'VULCAN_OIDC_SCHEME' => 'Use VULCAN_OIDC_ISSUER_URL instead'
      }

      deprecated_vars.each do |var, suggestion|
        warnings << "#{var} is deprecated - #{suggestion}" if ENV[var].present?
      end

      warnings.each do |warning|
        Rails.logger.warn "⚠️  #{warning}"
      end
    end

    def validate_redirect_uri
      redirect_uri = ENV['VULCAN_OIDC_REDIRECT_URI']
      return if redirect_uri.blank?

      begin
        uri = URI.parse(redirect_uri)

        unless uri.scheme&.match?(/^https?$/)
          Rails.logger.warn "⚠️  OIDC redirect URI should use HTTP/HTTPS: #{redirect_uri}"
        end

        unless uri.path&.end_with?('/users/auth/oidc/callback')
          Rails.logger.warn "⚠️  OIDC redirect URI should end with '/users/auth/oidc/callback': #{redirect_uri}"
        end

        Rails.logger.debug '✓ OIDC redirect URI format valid'
      rescue URI::InvalidURIError => e
        Rails.logger.warn "⚠️  Invalid OIDC redirect URI format: #{redirect_uri} - #{e.message}"
      end
    end

    def test_issuer_connectivity(uri)
      # Basic connectivity test with short timeout
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Head.new('/')
      response = http.request(request)

      Rails.logger.debug { "✓ OIDC issuer host accessible (HTTP #{response.code})" }
    rescue Net::OpenTimeout, Net::ReadTimeout
      Rails.logger.warn "⚠️  OIDC issuer host timeout: #{uri.host}"
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      Rails.logger.warn "⚠️  OIDC issuer host unreachable: #{uri.host} - #{e.message}"
    rescue StandardError => e
      Rails.logger.debug { "OIDC issuer connectivity test inconclusive: #{e.message}" }
    end

    def log_discovered_capabilities(discovery)
      endpoints = {
        'Authorization' => discovery['authorization_endpoint'],
        'Token' => discovery['token_endpoint'],
        'Userinfo' => discovery['userinfo_endpoint'],
        'Logout' => discovery['end_session_endpoint'],
        'JWKS' => discovery['jwks_uri']
      }

      available_endpoints = endpoints.select { |_, url| url.present? }

      Rails.logger.info '📋 OIDC Provider Capabilities:'
      available_endpoints.each do |name, _url|
        Rails.logger.info "    #{name}: ✓"
      end

      missing_endpoints = endpoints.select { |_, url| url.blank? }
      Rails.logger.info "   Missing optional endpoints: #{missing_endpoints.keys.join(', ')}" if missing_endpoints.any?
    end

    def should_test_connectivity?
      # Only test connectivity in production
      # Avoid network calls during development/test startup
      # Also respect WebMock in test environment
      Rails.env.production? && !defined?(WebMock)
    end

    # Helper methods for accessing configuration
    def issuer_url
      Settings.oidc.args&.dig('issuer') || ENV['VULCAN_OIDC_ISSUER_URL']
    end

    def client_id
      ENV['VULCAN_OIDC_CLIENT_ID']
    end

    def client_secret
      ENV['VULCAN_OIDC_CLIENT_SECRET']
    end
  end
end
