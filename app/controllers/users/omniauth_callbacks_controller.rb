# frozen_string_literal: true

module Users
  # When Omniauth callbacks come back successful, this is the controller
  # that is hit. Currently we don't have any provider-specific code, since
  # both LDAP and Github return data in a similar enough manner.
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    # Comprehensive error handling for various OmniAuth failure scenarios
    rescue_from Rack::OAuth2::Client::Error, with: :oauth_error
    rescue_from OmniAuth::Strategies::OAuth2::CallbackError, with: :omniauth_callback_error
    rescue_from Timeout::Error, with: :omniauth_timeout_error
    rescue_from Faraday::TimeoutError, with: :omniauth_timeout_error
    rescue_from ArgumentError, with: :omniauth_validation_error
    rescue_from ActiveRecord::RecordInvalid, with: :omniauth_record_error
    rescue_from StandardError, with: :omniauth_generic_error
    def all
      auth = request.env['omniauth.auth']

      Rails.logger.info "OmniAuth callback received for provider: #{auth.provider}, uid: #{auth.uid}"
      Rails.logger.debug { "OmniAuth info: email=#{auth.info.email}, name=#{auth.info.name}" }

      # Debug LDAP auth hash to understand email mapping issue
      if auth.provider == 'ldap'
        Rails.logger.debug { "LDAP raw_info: #{auth.extra.raw_info.inspect}" } if auth.extra&.raw_info
        Rails.logger.debug { "LDAP info hash: #{auth.info.to_h.inspect}" }
        Rails.logger.debug { "Full auth hash: #{auth.to_h.inspect}" }
      end

      user = User.from_omniauth(auth)

      # Store ID token in session for OIDC logout
      if auth.credentials&.id_token
        session[:id_token] = auth.credentials.id_token
        Rails.logger.info "Stored ID token in session for user: #{user.email}"
      else
        Rails.logger.warn "No ID token in OmniAuth credentials for user: #{user.email}"
      end

      flash.notice = I18n.t('devise.sessions.signed_in')
      sign_in_and_redirect(user) && return
    end

    alias ldap all
    alias github all
    alias oidc all

    def oauth_error(exception)
      Rails.logger.error "OAuth authentication error: #{exception.class} - #{exception.message}"
      Rails.logger.debug exception.backtrace.join("\n") if Rails.env.development?

      flash.alert = "OAuth error: #{exception.message}"
      redirect_to root_path
    end

    def omniauth_callback_error(exception)
      Rails.logger.error "OmniAuth callback error: #{exception.class} - #{exception.message}"
      Rails.logger.debug exception.backtrace.join("\n") if Rails.env.development?

      flash.alert = 'Authentication failed. Please try again or contact your administrator.'
      redirect_to new_user_session_path
    end

    def omniauth_timeout_error(exception)
      Rails.logger.error "OmniAuth timeout error: #{exception.class} - #{exception.message}"
      Rails.logger.debug exception.backtrace.join("\n") if Rails.env.development?

      flash.alert = 'Authentication timed out. Please try again.'
      redirect_to new_user_session_path
    end

    def omniauth_validation_error(exception)
      Rails.logger.error "OmniAuth validation error: #{exception.class} - #{exception.message}"
      Rails.logger.debug exception.backtrace.join("\n") if Rails.env.development?

      flash.alert = "Authentication failed: #{exception.message}"
      redirect_to new_user_session_path
    end

    def omniauth_record_error(exception)
      Rails.logger.error "OmniAuth database error: #{exception.class} - #{exception.message}"
      Rails.logger.debug exception.backtrace.join("\n") if Rails.env.development?

      flash.alert = 'Account creation failed. Please contact your administrator.'
      redirect_to new_user_session_path
    end

    def omniauth_generic_error(exception)
      Rails.logger.error "Unexpected OmniAuth error: #{exception.class} - #{exception.message}"
      Rails.logger.debug exception.backtrace.join("\n") if Rails.env.development?

      flash.alert = 'An unexpected error occurred during authentication. Please try again.'
      redirect_to new_user_session_path
    end
  end
end
