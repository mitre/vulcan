# frozen_string_literal: true

# This is the base mailer for the application. Things should only be
# placed here if they are shared between multiple mailers
class ApplicationMailer < ActionMailer::Base
  default from: ->(*) {
    # Use SMTP username as from address when available to ensure authentication alignment
    # This prevents domain mismatch issues between 'from' and SMTP authentication
    if Settings.smtp.enabled && Settings.smtp.settings['user_name'].present?
      Settings.smtp.settings['user_name']
    else
      Settings.contact_email
    end
  }
  layout 'mailer'
end
