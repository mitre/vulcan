# frozen_string_literal: true

# This is the base mailer for the application. Things should only be
# placed here if they are shared between multiple mailers
class ApplicationMailer < ActionMailer::Base
  default from: lambda { |*|
    # In production with SMTP enabled, use SMTP username for authentication alignment
    # Otherwise use contact_email for all other environments and cases
    if Rails.env.production? && Settings.smtp.enabled && Settings.smtp.settings&.dig('user_name').present?
      Settings.smtp.settings['user_name']
    else
      Settings.contact_email
    end
  }
  layout 'mailer'
end
