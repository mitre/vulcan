# frozen_string_literal: true

module Users
  # When Omniauth callbacks come back successful, this is the controller
  # that is hit. Currently we don't have any provider-specific code, since
  # both LDAP and Github return data in a similar enough manner.
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    # Error handling for OmniAuth failure scenarios.
    # Rails checks rescue_from in REVERSE order (last-defined = first-checked).
    # StandardError must be FIRST so specific subclasses defined after it take priority.
    rescue_from StandardError, with: :omniauth_generic_error
    rescue_from Rack::OAuth2::Client::Error, with: :oauth_error
    rescue_from OmniAuth::Strategies::OAuth2::CallbackError, with: :omniauth_callback_error
    rescue_from Timeout::Error, with: :omniauth_timeout_error
    rescue_from Faraday::TimeoutError, with: :omniauth_timeout_error
    rescue_from User::ProviderConflictError, with: :omniauth_provider_conflict
    rescue_from ArgumentError, with: :omniauth_validation_error
    rescue_from ActiveRecord::RecordInvalid, with: :omniauth_record_error
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

      return handle_identity_link(auth) if session.delete(:link_in_progress) && current_user

      user = User.from_omniauth(auth)

      # Notify user when their local account was auto-linked to an external provider.
      # `just_auto_linked?` is set by User.from_omniauth (no extra DB query needed).
      if user.just_auto_linked?
        provider_name = auth.provider.to_s == 'oidc' ? (Settings.oidc&.title || 'OIDC') : auth.provider.to_s.upcase
        flash.notice = "Your account has been linked to #{provider_name}. You can now sign in with either method."
      end

      # Record the auth method for this session so the profile can distinguish
      # "Signed in via Okta" from "Signed in via email and password" — this is
      # distinct from user.provider which records linked identities.
      session[:auth_method] = auth.provider.to_s.to_sym

      # Store ID token in session for OIDC logout
      if auth.credentials&.id_token
        session[:id_token] = auth.credentials.id_token
        Rails.logger.info "Stored ID token in session for user: #{user.email}"
      else
        Rails.logger.warn "No ID token in OmniAuth credentials for user: #{user.email}"
      end

      # Handle remember_me for OmniAuth logins
      # The checkbox sends remember_me=1 - check both regular params and omniauth.params
      # OmniAuth may pass form data via request.env['omniauth.params'] in some configurations
      omniauth_params = request.env['omniauth.params'] || {}
      should_remember = params[:remember_me] == '1' || omniauth_params['remember_me'] == '1'
      remember_me(user) if should_remember

      flash.notice ||= I18n.t('devise.sessions.signed_in')
      sign_in_and_redirect(user) && return
    end

    # Devise routes /users/auth/<provider>/callback to the action named
    # <provider>. The `all` implementation is provider-agnostic, so alias every
    # registered OmniAuth provider (ldap, github, and each OIDC provider) to it.
    # Deriving from Devise.omniauth_providers (populated at boot from the devise
    # initializer) keeps this in sync with what is actually registered and avoids
    # reading Settings at class-load time, which test stubs of Settings.oidc
    # would otherwise break.
    Devise.omniauth_providers.each { |provider| alias_method provider, :all }

    private

    def handle_identity_link(auth)
      session.delete(:link_provider)
      provider = auth.provider.to_s
      title = OidcProviderRegistry.title_for(provider)

      current_user.link_identity!(
        provider: provider,
        uid: auth.uid.to_s,
        email: auth.info.email,
        audit_reason: "Linked #{title} identity via profile"
      )

      flash.notice = "Your account has been linked to #{title}."
      redirect_to edit_user_registration_path
    rescue User::ProviderConflictError
      flash.alert = "This #{title} identity is already linked to another account. Please contact an administrator."
      redirect_to edit_user_registration_path
    end

    public

    def oauth_error(exception)
      # Log full details server-side for debugging.
      Rails.logger.error "OAuth authentication error: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace&.first(10)&.join("\n")

      # Do NOT include exception.message in the user-facing flash — Rack::OAuth2 errors
      # can include sensitive details (token hints, client config, redirect URIs).
      flash.alert = 'Authentication failed. Please try again or contact your administrator.'
      redirect_to new_user_session_path
    end

    def omniauth_callback_error(exception)
      Rails.logger.error "OmniAuth callback error: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace&.first(10)&.join("\n")

      flash.alert = 'Authentication failed. Please try again or contact your administrator.'
      redirect_to new_user_session_path
    end

    def omniauth_timeout_error(exception)
      Rails.logger.error "OmniAuth timeout error: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace&.first(10)&.join("\n")

      flash.alert = 'Authentication timed out. Please try again.'
      redirect_to new_user_session_path
    end

    def omniauth_provider_conflict(exception)
      auth = request.env['omniauth.auth']
      if auth
        session[:pending_link] = {
          provider: auth.provider.to_s,
          uid: auth.uid.to_s,
          email: auth.info.email,
          name: auth.info.name
        }
        Rails.logger.info "Provider conflict — pending link stored for #{auth.info.email} via #{auth.provider}"
        flash.alert = exception.message
        redirect_to new_user_session_path(link_pending: true)
      else
        Rails.logger.warn "Provider conflict (no auth data): #{exception.message}"
        flash.alert = exception.message
        redirect_to new_user_session_path
      end
    end

    def omniauth_validation_error(exception)
      Rails.logger.error "OmniAuth validation error: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace&.first(10)&.join("\n")

      flash.alert = "Authentication failed: #{exception.message}"
      redirect_to new_user_session_path
    end

    def omniauth_record_error(exception)
      Rails.logger.error "OmniAuth database error: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace&.first(10)&.join("\n")

      flash.alert = 'Account creation failed. Please contact your administrator.'
      redirect_to new_user_session_path
    end

    def omniauth_generic_error(exception)
      Rails.logger.error "Unexpected OmniAuth error: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace&.first(10)&.join("\n")

      flash.alert = 'An unexpected error occurred during authentication. Please try again.'
      redirect_to new_user_session_path
    end
  end
end
