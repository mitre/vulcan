# frozen_string_literal: true

# This must be handled as an initializer and cannot be handled inside of
# config/environments/production.rb due to our Settings model not being
# loaded at that point.

# Configure SMTP using Setting model with lazy loading to avoid database access during initialization
Rails.application.reloader.to_prepare do
  # Use ActiveSupport.on_load to delay Settings access until ActiveRecord is fully initialized
  ActiveSupport.on_load(:active_record) do
    # Skip if settings table doesn't exist (test environment initial setup)
    next unless ActiveRecord::Base.connection.table_exists?('settings')

    if Rails.env.production? && Setting.smtp_enabled && Setting.smtp_settings.present?
      # Create helper instance for SMTP validation caching
      smtp_helper = Class.new do
        include SmtpSettingsCacheHelper
      end.new

      # Validate SMTP connectivity with caching before applying configuration
      smtp_config = Setting.smtp_settings
      connectivity_result = smtp_helper.validate_smtp_connectivity(smtp_config)

      if connectivity_result&.dig('status') == 'success'
        Rails.application.config.action_mailer.delivery_method = :smtp
        Rails.application.config.action_mailer.perform_deliveries = true
        Rails.application.config.action_mailer.raise_delivery_errors = true
        if Setting.app_url.present?
          Rails.application.config.action_mailer.default_url_options = { host: URI.parse(Setting.app_url).host }
        end
        ActionMailer::Base.delivery_method = :smtp
        ActionMailer::Base.smtp_settings = smtp_config.transform_keys(&:to_sym)

        Rails.logger.info 'SMTP configuration applied successfully with cached validation'
      else
        Rails.logger.warn 'SMTP connectivity validation failed, skipping SMTP configuration'
        # Fallback to default delivery method in production
        Rails.application.config.action_mailer.delivery_method = :sendmail
      end
    end
  end
end
