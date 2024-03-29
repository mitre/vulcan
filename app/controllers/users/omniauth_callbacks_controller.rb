# frozen_string_literal: true

module Users
  # When Omniauth callbacks come back successful, this is the controller
  # that is hit. Currently we don't have any provider-specific code, since
  # both LDAP and Github return data in a similar enough manner.
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    rescue_from Rack::OAuth2::Client::Error, with: :oauth_error
    def all
      user = User.from_omniauth(request.env['omniauth.auth'])
      flash.notice = I18n.t('devise.sessions.signed_in')
      sign_in_and_redirect(user) && return
    end

    alias ldap all
    alias github all
    alias oidc all

    def oauth_error(exception)
      flash.alert = "OAuth error: #{exception.message}"
      redirect_to root_path
    end
  end
end
