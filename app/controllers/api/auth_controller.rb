# frozen_string_literal: true

module Api
  # JSON auth endpoints for SPA consumption: /api/auth/me, login, logout.
  class AuthController < BaseController
    skip_before_action :authenticate_user!, only: [:login]

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
        sign_in(user)
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
  end
end
