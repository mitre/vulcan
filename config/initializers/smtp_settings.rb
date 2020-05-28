# frozen_string_literal: true

# This must be handled as an initializer and cannot be handled inside of
# config/environments/production.rb due to our Settings model not being
# loaded at that point.

if Rails.env.production? && Settings.smtp.enabled
  Rails.application.config.action_mailer.delivery_method = :smtp

  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.smtp_settings = Settings.smtp.settings.transform_keys(&:to_sym)
end
