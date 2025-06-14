# frozen_string_literal: true

# General Settings Cache Helper
# Provides production-grade caching for frequently accessed general configuration values
module GeneralSettingsCacheHelper
  extend ActiveSupport::Concern
  include SettingsCacheHelper

  private

  # Cache frequently accessed app URL with validation
  def cached_app_url
    get_cached_settings('general_app_url', 'app_url') do
      validate_and_cache_app_url
    end
  end

  # Cache contact email with validation
  def cached_contact_email
    get_cached_settings('general_contact_email', 'contact_email') do
      validate_and_cache_contact_email
    end
  end

  # Cache local login configuration bundle
  def cached_local_login_config
    get_cached_settings('general_local_login', 'local_login_config') do
      build_local_login_config
    end
  end

  # Cache user registration configuration bundle
  def cached_user_registration_config
    get_cached_settings('general_user_registration', 'user_registration_config') do
      build_user_registration_config
    end
  end

  # Cache application branding/display configuration
  def cached_app_branding_config
    get_cached_settings('general_app_branding', 'app_branding_config') do
      build_app_branding_config
    end
  end

  # Warm general settings cache on startup
  def warm_general_settings_cache
    Rails.logger.info 'Warming general settings cache'

    Thread.new do
      begin
        # Warm frequently accessed settings
        cached_app_url if Setting.app_url.present?
        cached_contact_email if Setting.contact_email.present?
        cached_local_login_config
        cached_user_registration_config
        cached_app_branding_config

        Rails.logger.info 'General settings cache warmed successfully'
      rescue StandardError => e
        Rails.logger.warn "Failed to warm general settings cache: #{e.message}"
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to warm general settings cache: #{e.message}"
    end
  end

  # Validate and cache app URL
  def validate_and_cache_app_url
    app_url = Setting.app_url
    return nil if app_url.blank?

    begin
      uri = URI.parse(app_url)

      # Validate URL format
      raise ArgumentError, 'Invalid URL scheme' unless %w[http https].include?(uri.scheme)
      raise ArgumentError, 'Missing host' if uri.host.blank?

      validated_config = {
        url: app_url,
        host: uri.host,
        port: uri.port,
        scheme: uri.scheme,
        path: uri.path.presence || '/',
        validated_at: Time.current.iso8601,
        valid: true
      }

      # Cache for 2 hours (app URL changes rarely)
      cache_settings_data('general_app_url', 'app_url', validated_config, expires_in: 2.hours)
      validated_config
    rescue URI::InvalidURIError, ArgumentError => e
      Rails.logger.warn "Invalid app URL configuration: #{e.message}"

      invalid_config = {
        url: app_url,
        error: e.class.name,
        message: e.message,
        validated_at: Time.current.iso8601,
        valid: false
      }

      # Cache invalid config for shorter duration (30 minutes)
      cache_settings_data('general_app_url', 'app_url', invalid_config, expires_in: 30.minutes)
      invalid_config
    end
  end

  # Validate and cache contact email
  def validate_and_cache_contact_email
    contact_email = Setting.contact_email
    return nil if contact_email.blank?

    # Basic email validation
    email_valid = contact_email.match?(/\A[^@\s]+@[^@\s]+\z/)

    email_config = {
      email: contact_email,
      valid: email_valid,
      domain: email_valid ? contact_email.split('@').last : nil,
      validated_at: Time.current.iso8601
    }

    # Cache for 1 hour (contact email changes rarely)
    cache_settings_data('general_contact_email', 'contact_email', email_config, expires_in: 1.hour)
    email_config
  end

  # Build local login configuration bundle
  def build_local_login_config
    config = {
      enabled: Setting.local_login_enabled,
      session_timeout_minutes: Setting.local_login_session_timeout,
      email_confirmation_required: Setting.local_login_email_confirmation,
      built_at: Time.current.iso8601
    }

    # Cache for 30 minutes (login config may change during admin operations)
    cache_settings_data('general_local_login', 'local_login_config', config, expires_in: 30.minutes)
    config
  end

  # Build user registration configuration bundle
  def build_user_registration_config
    config = {
      # These would be additional user registration settings if they exist
      # For now, use the existing email confirmation setting
      email_confirmation_required: Setting.local_login_email_confirmation,
      contact_email: Setting.contact_email,
      built_at: Time.current.iso8601
    }

    # Cache for 30 minutes
    cache_settings_data('general_user_registration', 'user_registration_config', config, expires_in: 30.minutes)
    config
  end

  # Build application branding/display configuration
  def build_app_branding_config
    config = {
      app_url: Setting.app_url,
      contact_email: Setting.contact_email,
      # These would be additional branding settings if they exist
      # Adding placeholders for common branding elements
      application_name: 'Vulcan', # Could be a setting
      support_available: Setting.contact_email.present?,
      built_at: Time.current.iso8601
    }

    # Cache for 1 hour (branding changes rarely)
    cache_settings_data('general_app_branding', 'app_branding_config', config, expires_in: 1.hour)
    config
  end
end
