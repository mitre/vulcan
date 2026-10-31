# frozen_string_literal: true

module Api
  # JSON auth endpoints for SPA consumption: /api/auth/csrf, me, login, logout.
  class AuthController < BaseController
    skip_before_action :authenticate_user!, only: %i[csrf login]
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
    # login resets the token, so the caller fetches it again after signing
    # in. logout keeps the session, and the token with it; the HTML sign-out
    # (DELETE /users/sign_out) resets both.
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
        # event: :authentication runs Devise's CSRF cleanup hook, which
        # resets the session's authenticity token as the form login does; a
        # plain sign_in records a :set_user event and skips it.
        sign_in(user, event: :authentication)
        session[:auth_method] = :local
        render json: CurrentUserBlueprint.render(user)
      elsif user&.access_locked?
        render_account_locked
      else
        render_invalid_credentials
      end
    end

    def logout
      sign_out(current_user)
      render json: { message: 'Signed out successfully' }
    end

    private

    # A distinct 401 for a :lockable account that has hit the failed-attempt
    # threshold (STIG AC-07). Mirrors the HTML sign-in flow, which tells a
    # locked user to wait rather than silently rejecting a correct password.
    # render_problem comes from ErrorRendering (mixed into ApplicationController).
    def render_account_locked
      render_problem(
        type: :account_locked, title: 'Account locked', status: :unauthorized,
        detail: 'This account is temporarily locked due to too many failed sign-in attempts. ' \
                'Please try again later or reset your password.'
      )
    end
  end
end
