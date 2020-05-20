# frozen_string_literal: true

class Users
  # This controller exists so that we can block user registration if local user
  # login is disabled.
  class RegistrationsController < Devise::RegistrationsController
    def create
      if Settings.local_login.enabled
        super
      else
        redirect :back, alert: 'New user registration is not currently enabled.'
      end
    end
  end
end
