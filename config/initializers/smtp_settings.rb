# frozen_string_literal: true

# This must be handled as an initializer and cannot be handled inside of
# config/environments/production.rb due to our Settings model not being
# loaded at that point.

# Defer Settings access until after Rails initialization to avoid deprecation warnings
Rails.application.config.after_initialize do
  if Rails.env.production? && Settings.smtp.enabled && Settings.smtp.settings.present?
    Rails.application.config.action_mailer.delivery_method = :smtp
    Rails.application.config.action_mailer.perform_deliveries = true
    Rails.application.config.action_mailer.raise_delivery_errors = true
    if Settings.app_url.present?
      Rails.application.config.action_mailer.default_url_options = { host: URI.parse(Settings.app_url).host }
    end
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = Settings.smtp.settings.transform_keys(&:to_sym)
  end
end
