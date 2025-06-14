# frozen_string_literal: true

# Universal Provider Cache Helper
# DRY base for all provider-specific caching (LDAP, OIDC, SMTP, Slack)
# Supports multiple providers of the same type
module ProviderCacheHelper
  extend ActiveSupport::Concern
  include SettingsCacheHelper
  include CacheConfiguration

  private

  # Normalize provider configuration for consistent hash access
  def normalize_provider_config(config)
    return config unless config.is_a?(Hash)

    config.with_indifferent_access
  end

  # Generic provider cache identifier generator
  def generate_provider_cache_identifier(provider_type, provider_config, provider_id = 'default')
    # Normalize configuration for consistent access
    config = normalize_provider_config(provider_config)

    # Extract connection parameters based on provider type
    key_parts = case provider_type
                when 'ldap'
                  [config[:host], config[:port], config[:base], config[:method]]
                when 'smtp'
                  [config[:address], config[:port], config[:authentication]]
                when 'slack'
                  [Digest::SHA256.hexdigest(config[:api_token] || '')[0..16]]
                when 'oidc'
                  [config[:issuer], config[:client_id]]
                else
                  [provider_config.to_s]
                end

    # Include provider_id for multi-provider support
    cache_key_base = "#{provider_type}:#{provider_id}:#{key_parts.compact.join(':')}"
    Digest::SHA256.hexdigest(cache_key_base)[0..16]
  end

  # Generic connectivity test framework
  def test_provider_connectivity(provider_type, provider_config, provider_id = 'default')
    cache_identifier = generate_provider_cache_identifier(provider_type, provider_config, provider_id)

    get_cached_settings("#{provider_type}_connectivity", cache_identifier) do
      perform_connectivity_test(provider_type, provider_config, provider_id)
    end
  end

  # Generic provider validation framework
  def validate_provider_config(provider_type, provider_config, provider_id = 'default')
    cache_identifier = generate_provider_cache_identifier(provider_type, provider_config, provider_id)

    get_cached_settings("#{provider_type}_validation", cache_identifier) do
      perform_config_validation(provider_type, provider_config, provider_id)
    end
  end

  # Generic provider capabilities discovery
  def get_provider_capabilities(provider_type, provider_config, provider_id = 'default')
    cache_identifier = generate_provider_cache_identifier(provider_type, provider_config, provider_id)

    get_cached_settings("#{provider_type}_capabilities", cache_identifier) do
      fetch_provider_capabilities(provider_type, provider_config, provider_id)
    end
  end

  # Universal provider cache warming for multiple providers
  def warm_provider_caches(provider_type, providers_hash)
    return if providers_hash.blank?

    Rails.logger.info "Warming #{provider_type} provider caches for #{providers_hash.keys.count} providers"

    Thread.new do
      providers_hash.each do |provider_id, provider_config|
        test_provider_connectivity(provider_type, provider_config, provider_id)
        validate_provider_config(provider_type, provider_config, provider_id)
        get_provider_capabilities(provider_type, provider_config, provider_id)
        Rails.logger.info "#{provider_type.upcase} cache warmed for provider: #{provider_id}"
      rescue StandardError => e
        Rails.logger.warn "Failed to warm #{provider_type} cache for #{provider_id}: #{e.message}"
      end
      Rails.logger.info "#{provider_type.upcase} provider cache warming completed"
    rescue StandardError => e
      Rails.logger.warn "Failed to warm #{provider_type} provider caches: #{e.message}"
    end
  end

  # Perform actual connectivity test based on provider type
  def perform_connectivity_test(provider_type, provider_config, provider_id)
    case provider_type
    when 'ldap'
      test_ldap_connectivity(provider_config, provider_id)
    when 'smtp'
      test_smtp_connectivity(provider_config, provider_id)
    when 'slack'
      test_slack_connectivity(provider_config, provider_id)
    when 'oidc'
      test_oidc_connectivity(provider_config, provider_id)
    else
      { status: 'unsupported', provider_type: provider_type, tested_at: Time.current.iso8601 }
    end
  end

  # Test TCP connectivity (common for LDAP, SMTP)
  def test_tcp_connectivity(host, port, provider_type, provider_id, timeout: nil)
    # Use configured timeout or default
    connection_timeout = timeout || timeout_for(provider_type)
    begin
      Timeout.timeout(connection_timeout) do
        TCPSocket.open(host, port).close
      end

      {
        status: 'success',
        provider_type: provider_type,
        provider_id: provider_id,
        host: host,
        port: port,
        tested_at: Time.current.iso8601
      }
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
      Rails.logger.warn "#{provider_type.upcase} connectivity test failed for #{provider_id}: #{e.message}"

      {
        status: 'failed',
        provider_type: provider_type,
        provider_id: provider_id,
        host: host,
        port: port,
        error: e.class.name,
        message: e.message,
        tested_at: Time.current.iso8601
      }
    end
  end

  # LDAP-specific connectivity test
  def test_ldap_connectivity(provider_config, provider_id)
    config = normalize_provider_config(provider_config)
    host = config[:host]
    port = config[:port] || 389

    result = test_tcp_connectivity(host, port, 'ldap', provider_id)

    # Cache with configured durations
    cache_identifier = generate_provider_cache_identifier('ldap', provider_config, provider_id)
    expires_in = cache_duration_for('ldap', 'connectivity', success: result[:status] == 'success')
    cache_settings_data('ldap_connectivity', cache_identifier, result, expires_in: expires_in)

    result
  end

  # SMTP-specific connectivity test
  def test_smtp_connectivity(provider_config, provider_id)
    config = normalize_provider_config(provider_config)
    host = config[:address]
    port = config[:port] || 587

    result = test_tcp_connectivity(host, port, 'smtp', provider_id)

    # Cache with configured durations
    cache_identifier = generate_provider_cache_identifier('smtp', provider_config, provider_id)
    expires_in = cache_duration_for('smtp', 'connectivity', success: result[:status] == 'success')
    cache_settings_data('smtp_connectivity', cache_identifier, result, expires_in: expires_in)

    result
  end

  # Slack-specific connectivity test (API-based)
  def test_slack_connectivity(provider_config, provider_id)
    # This would make actual Slack API call in production
    # For now, simulate the test
    result = {
      status: 'success', # Would be based on actual API test
      provider_type: 'slack',
      provider_id: provider_id,
      api_token_valid: true, # Would check actual token
      tested_at: Time.current.iso8601
    }

    # Cache with configured durations
    cache_identifier = generate_provider_cache_identifier('slack', provider_config, provider_id)
    expires_in = cache_duration_for('slack', 'api', success: result[:status] == 'success')
    cache_settings_data('slack_connectivity', cache_identifier, result, expires_in: expires_in)

    result
  end

  # OIDC-specific connectivity test
  def test_oidc_connectivity(provider_config, provider_id)
    config = normalize_provider_config(provider_config)
    # This would test OIDC discovery endpoint
    issuer = config[:issuer]

    begin
      uri = URI("#{issuer}/.well-known/openid-configuration")
      result = test_tcp_connectivity(uri.host, uri.port || 443, 'oidc', provider_id)

      # Cache with configured durations
      cache_identifier = generate_provider_cache_identifier('oidc', provider_config, provider_id)
      expires_in = cache_duration_for('oidc', 'discovery', success: result[:status] == 'success')
      cache_settings_data('oidc_connectivity', cache_identifier, result, expires_in: expires_in)

      result
    rescue URI::InvalidURIError => e
      {
        status: 'failed',
        provider_type: 'oidc',
        provider_id: provider_id,
        issuer: issuer,
        error: 'invalid_uri',
        message: e.message,
        tested_at: Time.current.iso8601
      }
    end
  end

  # Generic config validation (override in specific helpers)
  def perform_config_validation(provider_type, _provider_config, provider_id)
    {
      status: 'success',
      provider_type: provider_type,
      provider_id: provider_id,
      config_valid: true,
      validated_at: Time.current.iso8601
    }
  end

  # Generic capabilities discovery (override in specific helpers)
  def fetch_provider_capabilities(provider_type, _provider_config, provider_id)
    {
      provider_type: provider_type,
      provider_id: provider_id,
      capabilities: [],
      fetched_at: Time.current.iso8601
    }
  end
end
