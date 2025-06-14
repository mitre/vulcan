# frozen_string_literal: true

# Universal Settings Cache Helper
# Provides production-grade caching for all Vulcan settings systems
# Features: cache key namespacing, fallback strategies, metrics, warming, request locking
module SettingsCacheHelper
  extend ActiveSupport::Concern
  include CacheConfiguration

  private

  # Universal cache key builder with proper namespacing for multi-tenant deployments
  def build_settings_cache_key(cache_type, identifier)
    app_name = Rails.application.class.module_parent.name.underscore
    environment = Rails.env

    "#{app_name}:#{environment}:#{CacheConfiguration::CACHE_VERSION}:#{cache_type}:#{identifier}"
  end

  # Generic settings cache read with fallback handling
  def get_cached_settings(cache_type, identifier, &fallback_block)
    cache_key = build_settings_cache_key(cache_type, identifier)

    begin
      cached = Rails.cache.read(cache_key)

      if cached
        # Cache hit - log metrics
        log_settings_cache_metrics('hit', cache_type, identifier)
        cached
      else
        # Cache miss - log metrics and execute fallback
        log_settings_cache_metrics('miss', cache_type, identifier)

        if fallback_block
          fresh_data = yield
          cache_settings_data(cache_type, identifier, fresh_data) if fresh_data
          return fresh_data
        end

        nil
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to read settings cache for #{cache_type}:#{identifier}: #{e.message}"
      log_settings_cache_metrics('error', cache_type, identifier, error: e.message)

      # Graceful degradation - execute fallback if provided
      return yield if fallback_block

      nil
    end
  end

  # Generic settings cache write with error handling
  def cache_settings_data(cache_type, identifier, data, expires_in: nil)
    # Use configured duration if not specified
    cache_duration = expires_in || cache_duration_for('general', 'settings')
    cache_key = build_settings_cache_key(cache_type, identifier)

    # Add caching metadata and make hash indifferent to access type
    if data.is_a?(Hash)
      # Use HashWithIndifferentAccess for consistent symbol/string access
      enhanced_data = data.with_indifferent_access

      enhanced_data[:expires_at] = cache_duration.from_now
      enhanced_data[:cached_at] = Time.current
      enhanced_data[:vulcan_cache_version] = CacheConfiguration::CACHE_VERSION
      enhanced_data[:cache_type] = cache_type
    else
      enhanced_data = data
    end

    begin
      Rails.cache.write(cache_key, enhanced_data, expires_in: cache_duration)
      expires_at = enhanced_data.is_a?(Hash) ? enhanced_data[:expires_at] : cache_duration.from_now
      log_settings_cache_metrics('write', cache_type, identifier, expires_at: expires_at)
    rescue StandardError => e
      Rails.logger.warn "Failed to cache settings data for #{cache_type}:#{identifier}: #{e.message}"
      log_settings_cache_metrics('write_error', cache_type, identifier, error: e.message)
      # Continue without caching - graceful degradation
    end
  end

  # Request locking to prevent concurrent validation requests
  def with_settings_request_lock(cache_type, identifier, timeout: nil)
    # Use configured timeout if not specified
    lock_timeout = timeout || request_lock_timeout_for(cache_type)
    request_lock_key = build_settings_cache_key("#{cache_type}_request_lock", identifier)

    begin
      if Rails.cache.exist?(request_lock_key)
        log_settings_cache_metrics('concurrent_request_blocked', cache_type, identifier,
                                   reason: 'request_in_progress')
        return nil
      end

      # Set request lock
      Rails.cache.write(request_lock_key, true, expires_in: lock_timeout)

      yield if block_given?
    rescue StandardError => e
      Rails.logger.warn "Settings request lock failed for #{cache_type}:#{identifier}: #{e.message}"
      # Continue without locking - graceful degradation
      yield if block_given?
    ensure
      # Always clear the request lock
      begin
        Rails.cache.delete(request_lock_key)
      rescue StandardError => e
        Rails.logger.warn "Failed to clear settings request lock: #{e.message}"
      end
    end
  end

  # Validate cached settings with version check
  def validate_cached_settings(cached_data, cache_type, identifier)
    return false unless cached_data.is_a?(Hash)

    # Check cache version for forward compatibility
    cache_version = cached_data['vulcan_cache_version']
    if cache_version != '1.1'
      log_settings_cache_metrics('cache_invalidated', cache_type, identifier,
                                 reason: 'version_mismatch',
                                 cached_version: cache_version,
                                 expected_version: '1.1')
      Rails.cache.delete(build_settings_cache_key(cache_type, identifier))
      return false
    end

    # Check expiration (backup to Rails.cache built-in expiration)
    expires_at = cached_data['expires_at']
    if expires_at && Time.zone.parse(expires_at.to_s) < Time.current
      log_settings_cache_metrics('cache_invalidated', cache_type, identifier,
                                 reason: 'expired',
                                 expired_at: expires_at)
      Rails.cache.delete(build_settings_cache_key(cache_type, identifier))
      return false
    end

    true
  end

  # Log cache metrics for monitoring and observability
  def log_settings_cache_metrics(event_type, cache_type, identifier, additional_data = {})
    metrics_data = {
      event: "settings_cache_#{event_type}",
      cache_type: cache_type,
      identifier: identifier,
      timestamp: Time.current.iso8601,
      cache_version: '1.1'
    }.merge(additional_data)

    # Log as structured JSON for easy parsing by monitoring tools
    Rails.logger.info "[SETTINGS_CACHE_METRICS] #{metrics_data.to_json}"

    # Optional: Send to monitoring service (e.g., DataDog, New Relic)
    # if defined?(StatsD)
    #   StatsD.increment("vulcan.settings.cache.#{cache_type}.#{event_type}")
    # end
  end

  # Generic settings validation helper
  def validate_settings_connectivity(cache_type, identifier)
    return false unless validation_block

    with_settings_request_lock(cache_type, identifier) do
      result = yield
      log_settings_cache_metrics('validation_success', cache_type, identifier)
      result
    rescue StandardError => e
      log_settings_cache_metrics('validation_failed', cache_type, identifier,
                                 error: e.class.name,
                                 message: e.message)
      false
    end
  end
end
