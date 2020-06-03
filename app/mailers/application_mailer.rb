# frozen_string_literal: true

# This is the base mailer for the application. Things should only be
# placed here if they are shared between multiple mailers
class ApplicationMailer < ActionMailer::Base
  default from: ->(*) { Settings.contact_email }
  layout 'mailer'
end
