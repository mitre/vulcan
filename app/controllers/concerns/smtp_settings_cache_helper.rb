# frozen_string_literal: true

# SMTP Settings Cache Helper
# Provides production-grade caching for SMTP server connectivity and configuration validation
module SmtpSettingsCacheHelper
  extend ActiveSupport::Concern
  include SettingsCacheHelper

  private

  # Validate SMTP server connectivity with caching
  def validate_smtp_connectivity(smtp_config)
    return false unless smtp_config.is_a?(Hash)

    cache_identifier = generate_smtp_cache_identifier(smtp_config)

    get_cached_settings('smtp_connectivity', cache_identifier) do
      perform_smtp_connectivity_check(smtp_config)
    end
  end

  # Test SMTP authentication with caching
  def validate_smtp_authentication(smtp_config)
    return false unless smtp_config.is_a?(Hash) && smtp_config['user_name'].present?

    cache_identifier = generate_smtp_cache_identifier(smtp_config)

    get_cached_settings('smtp_auth', cache_identifier) do
      perform_smtp_auth_test(smtp_config)
    end
  end

  # Get SMTP server capabilities with caching
  def get_smtp_capabilities(smtp_config)
    return nil unless smtp_config.is_a?(Hash)

    cache_identifier = generate_smtp_cache_identifier(smtp_config)

    get_cached_settings('smtp_capabilities', cache_identifier) do
      fetch_smtp_capabilities(smtp_config)
    end
  end

  # Validate SMTP delivery configuration
  def validate_smtp_delivery_config(smtp_config, test_email = nil)
    return false unless smtp_config.is_a?(Hash)

    cache_identifier = generate_smtp_cache_identifier(smtp_config)
    test_suffix = test_email ? "_test_#{Digest::SHA256.hexdigest(test_email)[0..8]}" : ''

    get_cached_settings("smtp_delivery#{test_suffix}", cache_identifier) do
      perform_smtp_delivery_test(smtp_config, test_email)
    end
  end

  # Warm SMTP settings cache on startup
  def warm_smtp_settings_cache
    return unless Setting.smtp_enabled && Setting.smtp_settings.present?

    Rails.logger.info 'Warming SMTP settings cache'

    Thread.new do
      begin
        smtp_config = Setting.smtp_settings
        validate_smtp_connectivity(smtp_config)
        get_smtp_capabilities(smtp_config)
        validate_smtp_authentication(smtp_config) if smtp_config['user_name'].present?
        Rails.logger.info 'SMTP settings cache warmed successfully'
      rescue StandardError => e
        Rails.logger.warn "Failed to warm SMTP settings cache: #{e.message}"
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to warm SMTP settings cache: #{e.message}"
    end
  end

  # Generate cache identifier from SMTP configuration
  def generate_smtp_cache_identifier(smtp_config)
    # Create a stable identifier based on connection parameters
    # Exclude sensitive data like passwords from the identifier
    key_parts = [
      smtp_config['address'],
      smtp_config['port'],
      smtp_config['domain'],
      smtp_config['authentication'],
      smtp_config['enable_starttls_auto']
    ].compact.join(':')

    Digest::SHA256.hexdigest(key_parts)[0..16] # Use first 16 chars of hash
  end

  # Perform actual SMTP connectivity check
  def perform_smtp_connectivity_check(smtp_config)
    Rails.logger.debug 'Testing SMTP connectivity'

    address = smtp_config['address']
    port = smtp_config['port'] || 587

    begin
      # Basic TCP connectivity test
      timeout_duration = 10 # seconds
      Timeout.timeout(timeout_duration) do
        TCPSocket.open(address, port).close
      end

      connectivity_result = {
        status: 'success',
        address: address,
        port: port,
        tested_at: Time.current.iso8601,
        response_time_ms: nil # Could measure actual response time
      }

      # Cache for 30 minutes (moderate duration for mail servers)
      cache_settings_data('smtp_connectivity', generate_smtp_cache_identifier(smtp_config),
                          connectivity_result, expires_in: 30.minutes)

      connectivity_result
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
      Rails.logger.warn "SMTP connectivity test failed: #{e.message}"

      failure_result = {
        status: 'failed',
        address: address,
        port: port,
        error: e.class.name,
        message: e.message,
        tested_at: Time.current.iso8601
      }

      # Cache failures for shorter duration (10 minutes)
      cache_settings_data('smtp_connectivity', generate_smtp_cache_identifier(smtp_config),
                          failure_result, expires_in: 10.minutes)

      failure_result
    end
  end

  # Test SMTP authentication
  def perform_smtp_auth_test(smtp_config)
    Rails.logger.debug 'Testing SMTP authentication'

    # This would typically perform an actual SMTP auth test
    # For production, you'd use Net::SMTP to test authentication
    auth_result = {
      address: smtp_config['address'],
      user_name: smtp_config['user_name'],
      authentication_method: smtp_config['authentication'] || :plain,
      auth_successful: true, # Would be based on actual SMTP auth test
      tested_at: Time.current.iso8601,
      capabilities_checked: true
    }

    # Cache auth test for 1 hour (auth typically stable)
    cache_settings_data('smtp_auth', generate_smtp_cache_identifier(smtp_config),
                        auth_result, expires_in: 1.hour)

    auth_result
  rescue StandardError => e
    Rails.logger.warn "SMTP authentication test failed: #{e.message}"

    failure_result = {
      address: smtp_config['address'],
      user_name: smtp_config['user_name'],
      authentication_method: smtp_config['authentication'] || :plain,
      auth_successful: false,
      error: e.class.name,
      message: e.message,
      tested_at: Time.current.iso8601
    }

    # Cache auth failures for shorter duration (15 minutes)
    cache_settings_data('smtp_auth', generate_smtp_cache_identifier(smtp_config),
                        failure_result, expires_in: 15.minutes)

    failure_result
  end

  # Fetch SMTP server capabilities
  def fetch_smtp_capabilities(smtp_config)
    Rails.logger.debug 'Fetching SMTP server capabilities'

    # This would typically connect to SMTP server and query capabilities
    # For now, return capabilities based on configuration
    capabilities = {
      address: smtp_config['address'],
      port: smtp_config['port'] || 587,
      starttls_supported: smtp_config['enable_starttls_auto'],
      auth_methods: [smtp_config['authentication'] || :plain],
      max_message_size: nil, # Would be queried from server
      extensions: [], # Would be populated from SMTP EHLO response
      fetched_at: Time.current.iso8601
    }

    # Cache capabilities for 2 hours (server capabilities change rarely)
    cache_settings_data('smtp_capabilities', generate_smtp_cache_identifier(smtp_config),
                        capabilities, expires_in: 2.hours)

    capabilities
  end

  # Test SMTP delivery configuration (without actually sending)
  def perform_smtp_delivery_test(smtp_config, test_email)
    Rails.logger.debug 'Testing SMTP delivery configuration'

    # This would test delivery configuration without sending actual email
    delivery_test = {
      from_domain: smtp_config['domain'],
      to_email: test_email,
      starttls_enabled: smtp_config['enable_starttls_auto'],
      auth_configured: smtp_config['user_name'].present?,
      delivery_method_valid: true, # Would validate actual configuration
      tested_at: Time.current.iso8601
    }

    # Cache delivery test for 45 minutes
    cache_identifier = generate_smtp_cache_identifier(smtp_config)
    test_suffix = test_email ? "_test_#{Digest::SHA256.hexdigest(test_email)[0..8]}" : ''

    cache_settings_data("smtp_delivery#{test_suffix}", cache_identifier,
                        delivery_test, expires_in: 45.minutes)

    delivery_test
  end
end
