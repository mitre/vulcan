# frozen_string_literal: true

module Api
  # JSON auth endpoints for SPA consumption: /api/auth/csrf, me, login, logout.
  class AuthController < BaseController
    # Signing in and signing out both end the session the caller arrived
    # with, so neither may be refused because that session timed out: a
    # lookup of the signed-in user would run the timeout hook, which signs
    # out and throws. Devise::SessionsController sets the same flag for both
    # create and destroy.
    prepend_before_action(only: %i[login logout]) { request.env['devise.skip_timeout'] = true }
    skip_before_action :authenticate_user!, only: %i[csrf login]
    # devise-security's password-expiry and paranoid-verification redirects
    # run for HTML-format requests and look up the signed-in user, which on
    # a timed-out or superseded session signs out and throws. Both actions
    # that need no sign-in must answer on the first call even when the format
    # resolves to HTML — which it does for a JSON POST that sends no Accept
    # header, or Accept: */* — so both skip the pair; every action that needs
    # a sign-in keeps both checks.
    skip_before_action :handle_password_change, :handle_paranoid_verification, only: %i[csrf login]
    before_action :require_local_login_enabled!, only: [:login]

    # Issues the authenticity token bound to the caller's session, creating
    # the session when none exists. A frontend that is not rendered by the
    # Rails layout needs this before it can POST login (login is
    # CSRF-protected), and Devise redirects signed-in users away from the
    # sign-in page, so the layout's meta tag is unreachable to it. The token
    # is only usable together with the session cookie, so the response must
    # never be cached. This issues a token; it exempts nothing from
    # verify_authenticity_token.
    #
    # login resets the token and logout resets the whole session, so the
    # caller fetches a token again after either.
    def csrf
      no_store
      render json: { csrf_token: form_authenticity_token }
    end

    def me
      render json: CurrentUserBlueprint.render(current_user)
    end

    def login
      user = User.find_by(email: params[:email])

      # Route the password check through Devise's account-state machinery
      # (valid_for_authentication? + active_for_authentication?), exactly as
      # SessionsController and the omniauth link flow do. A bare
      # valid_password? + sign_in would skip :lockable (STIG AC-07 — no
      # failed_attempts increment, locked accounts still signed in) and
      # :confirmable/active-state checks. Rate limiting for this path lives
      # in the shared rack_attack login throttles.
      if user&.valid_for_authentication? { user.valid_password?(params[:password]) } &&
         user.active_for_authentication?
        # A sign-in replaces whatever session the caller had. sign_out reads
        # the old user without running the fetch callbacks, so a timed-out
        # or superseded session neither throws from those hooks nor makes
        # sign_in return early as "already signed in", which would keep the
        # stale session. It is warden.logout(:user) though: it drops the
        # previous occupant's warden keys (and runs their session_traceable /
        # session_limitable revocations) but does NOT reset the session, so
        # everything else they left behind would become the new user's —
        # session[:id_token] above all, which SessionsController#destroy
        # sends to the OIDC provider as the new user's id_token_hint. Devise's
        # require_no_authentication keeps the HTML sign-in anonymous, so this
        # endpoint is the only one that has to reset the session itself.
        preserving_consent_acknowledgment do
          sign_out(:user)
          reset_session
        end
        sign_in(user)
        session[:auth_method] = :local
        render json: CurrentUserBlueprint.render(user)
      elsif user&.access_locked?
        render_account_locked
      else
        render_invalid_credentials
      end
    end

    # sign_out with no scope takes Devise's sign_out_all_scopes path:
    # warden.logout resets the whole session, as the HTML sign-out does, so
    # the authenticity token, auth_method and the consent acknowledgment go
    # with it.
    def logout
      sign_out
      render json: { message: 'Signed out successfully' }
    end
  end
end
