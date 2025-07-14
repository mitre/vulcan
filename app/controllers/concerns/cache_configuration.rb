# frozen_string_literal: true

# Cache Configuration Constants
# Centralized timeouts and cache durations for consistent behavior
module CacheConfiguration
  extend ActiveSupport::Concern

  # Connection timeout constants for provider testing
  TIMEOUTS = {
    ldap_connection: 5.seconds,
    smtp_connection: 10.seconds,
    slack_api: 15.seconds,
    oidc_discovery: 10.seconds,
    default_tcp: 10.seconds
  }.freeze

  # Cache expiration durations based on data stability
  CACHE_DURATIONS = {
    # Connectivity tests - network can be variable
    connectivity_success: 15.minutes,
    connectivity_failure: 5.minutes,

    # Authentication results - more stable
    authentication_success: 1.hour,
    authentication_failure: 15.minutes,

    # Provider capabilities - very stable
    capabilities: 2.hours,

    # Configuration validation - stable
    config_validation: 1.hour,

    # General application settings - moderately stable
    general_settings: 30.minutes,

    # OIDC discovery documents - stable endpoints
    oidc_discovery: 1.hour,

    # Provider-specific overrides
    smtp_connectivity_success: 30.minutes,  # Mail servers more stable
    smtp_connectivity_failure: 10.minutes,

    slack_api_success: 1.hour,              # API tokens stable
    slack_api_failure: 15.minutes
  }.freeze

  # Request lock timeouts to prevent concurrent API calls
  REQUEST_LOCK_TIMEOUTS = {
    connectivity_test: 5.seconds,
    authentication: 10.seconds,
    capabilities_fetch: 15.seconds,
    general_settings: 5.seconds
  }.freeze

  # Cache version for invalidation during upgrades
  CACHE_VERSION = '1.1'

  # Helper methods for consistent duration lookup
  module_function

  def cache_duration_for(provider_type, operation, success: true)
    key = "#{provider_type}_#{operation}_#{success ? 'success' : 'failure'}".to_sym
    CACHE_DURATIONS[key] || CACHE_DURATIONS["#{operation}_#{success ? 'success' : 'failure'}".to_sym] || 15.minutes
  end

  def timeout_for(provider_type)
    key = "#{provider_type}_connection".to_sym
    TIMEOUTS[key] || TIMEOUTS[:default_tcp]
  end

  def request_lock_timeout_for(operation)
    REQUEST_LOCK_TIMEOUTS[operation.to_sym] || REQUEST_LOCK_TIMEOUTS[:connectivity_test]
  end
end
