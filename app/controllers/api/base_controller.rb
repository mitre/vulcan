# frozen_string_literal: true

module Api
  ##
  # Base controller for all API endpoints
  #
  # Provides:
  # - Consistent JSON error handling
  # - Correct HTTP status codes (401 vs 403)
  # - Skips HTML-only before_actions
  #
  # All API controllers should inherit from this instead of ApplicationController
  #
  class BaseController < ApplicationController
    # Skip HTML-only actions - APIs don't need navigation or notifications
    skip_before_action :setup_navigation
    skip_before_action :check_access_request_notifications

    # Standardized JSON error responses with correct HTTP semantics

    # 400 Bad Request - Client sent invalid parameters
    rescue_from ActionController::ParameterMissing do |exception|
      render json: { error: exception.message }, status: :bad_request
    end

    # 404 Not Found - Resource doesn't exist
    rescue_from ActiveRecord::RecordNotFound do |_exception|
      render json: { error: 'Not found' }, status: :not_found
    end

    # 403 Forbidden - Authenticated but not authorized
    # Note: 401 Unauthorized is for unauthenticated requests (handled by Devise)
    rescue_from NotAuthorizedError do |exception|
      render json: { error: exception.message }, status: :forbidden
    end
  end
end
