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

      if user&.valid_password?(params[:password])
        sign_in(user)
        session[:auth_method] = :local
        render json: CurrentUserBlueprint.render(user)
      else
        render json: { error: 'Invalid email or password' }, status: :unauthorized
      end
    end

    def logout
      sign_out(current_user)
      render json: { message: 'Signed out successfully' }
    end
  end
end
