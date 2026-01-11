# frozen_string_literal: true

module Api
  module Auth
    ##
    # Modern authentication API endpoints
    #
    # Provides:
    # - POST /api/auth/login - Login with email/password
    # - DELETE /api/auth/logout - Logout (session invalidation)
    # - GET /api/auth/me - Get current authenticated user
    #
    # Designed to be backend-agnostic (works with Devise now, Rodauth later)
    #
    class SessionsController < Api::BaseController
      # Skip authentication for login/logout (already in session)
      skip_before_action :authenticate_user!, only: %i[create destroy]

      # POST /api/auth/login
      def create
        user = User.find_by(email: params[:email])

        if user&.valid_password?(params[:password])
          sign_in(:user, user)
          render json: { user: user.as_json(only: %i[id email admin]) }, status: :ok
        else
          head :unauthorized
        end
      end

      # DELETE /api/auth/logout
      def destroy
        sign_out(:user) if user_signed_in?
        head :no_content
      end

      # GET /api/auth/me
      def show
        if current_user
          render json: { user: current_user.as_json(only: %i[id email admin]) }, status: :ok
        else
          head :unauthorized
        end
      end
    end
  end
end
