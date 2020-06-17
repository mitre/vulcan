# frozen_string_literal: true

module Users
  # This controller exists so that we can block user registration if local user
  # login is disabled.
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_permitted_parameters

    def create
      if Settings.local_login.enabled
        super
      else
        redirect_back(fallback_location: new_user_session_path, alert: I18n.t('devise.registrations.disabled'))
      end
    end

    protected

    def update_resource(resource, params)
      if resource.provider.nil?
        super
      else
        resource.update_without_password(params)
      end
    end

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
      devise_parameter_sanitizer.permit(:account_update, keys: [:name])
    end
  end
end
