# frozen_string_literal: true

module Users
  # This controller exists so that we can block user registration if local user
  # login is disabled.
  class RegistrationsController < Devise::RegistrationsController
    def create
      if Settings.local_login.enabled
        super
      else
        redirect_back(fallback_location: new_user_session_path, alert: I18n.t('devise.registrations.disabled'))
      end
    end
  end
end
