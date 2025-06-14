# frozen_string_literal: true

# Universal Settings Cache Warming
# Multi-provider-ready cache warming for all settings systems

Rails.application.reloader.to_prepare do
  # Use ActiveSupport.on_load to delay Settings access until ActiveRecord is fully initialized
  ActiveSupport.on_load(:active_record) do
    # Check if settings table exists before trying to warm caches
    begin
      # Test database connection and table existence
      next unless ActiveRecord::Base.connection.table_exists?('settings')
    rescue StandardError => e
      Rails.logger.warn "Skipping settings cache warming: #{e.message}"
      next
    end

  # Create a comprehensive multi-provider cache warming controller
  cache_warmer = Class.new do
    include OidcDiscoveryHelper
    include ProviderCacheHelper
    include GeneralSettingsCacheHelper

    def session
      {} # Minimal session for cache warming
    end

    # Make warming methods accessible
    public :warm_oidc_discovery_cache, :warm_general_settings_cache

    def warm_all_settings_caches
      Rails.logger.info 'Starting multi-provider settings cache warming'

      # Wrap all cache warming in error handling
      begin
        # Warm general settings cache (always needed)
        warm_general_settings_cache

        # Warm OIDC providers (supports multiple)
        warm_oidc_providers

        # Warm LDAP providers (supports multiple)
        warm_ldap_providers

        # Warm SMTP providers (supports multiple)
        warm_smtp_providers

        # Warm Slack providers (supports multiple)
        warm_slack_providers

        Rails.logger.info 'Multi-provider settings cache warming completed'
      rescue StandardError => e
        Rails.logger.warn "Settings cache warming failed: #{e.message}"
      end
    end

    private

    def warm_oidc_providers
      return unless Setting.oidc_enabled && (Setting.oidc_discovery && Setting.oidc_args.present?)

      # Current single provider support
      warm_oidc_discovery_cache

      # Future multiple providers support:
      # Setting.oidc_providers&.each do |provider_id, provider_config|
      #   warm_provider_caches('oidc', { provider_id => provider_config })
      # end
    end

    def warm_ldap_providers
      return unless Setting.ldap_enabled && Setting.ldap_servers.present?

      # Multi-provider ready: warm each LDAP server
      warm_provider_caches('ldap', Setting.ldap_servers)
    end

    def warm_smtp_providers
      return unless Setting.smtp_enabled && Setting.smtp_settings.present?

      # Current single provider, but structured for multiple
      smtp_providers = { 'default' => Setting.smtp_settings }
      warm_provider_caches('smtp', smtp_providers)

      # Future multiple providers support:
      # warm_provider_caches('smtp', Setting.smtp_providers) if Setting.smtp_providers.present?
    end

    def warm_slack_providers
      return unless Setting.slack_enabled && Setting.slack_api_token.present?

      # Current single provider, but structured for multiple
      slack_providers = { 'default' => { 'api_token' => Setting.slack_api_token } }
      warm_provider_caches('slack', slack_providers)

      # Future multiple providers support:
      # warm_provider_caches('slack', Setting.slack_providers) if Setting.slack_providers.present?
    end
  end.new

  # Warm all caches asynchronously
  cache_warmer.warm_all_settings_caches
  end
end
