# frozen_string_literal: true

module Users
  # When Omniauth callbacks come back successful, this is the controller
  # that is hit. Currently we don't have any provider-specific code, since
  # both LDAP and Github return data in a similar enough manner.
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    rescue_from Rack::OAuth2::Client::Error, with: :oauth_error
    def all
      auth = request.env['omniauth.auth']

      Rails.logger.info "OmniAuth callback received for provider: #{auth.provider}, uid: #{auth.uid}"
      Rails.logger.debug { "OmniAuth info: email=#{auth.info.email}, name=#{auth.info.name}" }

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
  end
end
