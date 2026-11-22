# frozen_string_literal: true

module Api
  ##
  # Base controller for all API endpoints
  #
  # Provides:
  # - Consistent JSON error handling
  # - Correct HTTP status codes (401 vs 403)
  # - Never runs the HTML layout callbacks
  # - Returns 401 JSON instead of redirecting for unauthenticated requests
  #
  # All API controllers should inherit from this instead of ApplicationController
  #
  class BaseController < ApplicationController
    def authenticate_user!(*)
      if api_token_request? || user_signed_in?
        super
      else
        render_not_authenticated
      end
    end

    # Standardized problem-details error responses with correct HTTP
    # semantics. Bodies come from ErrorRendering — API endpoints answer JSON
    # regardless of the Accept header, so each rescue calls the renderer
    # directly instead of going through a format negotiation.

    # 400 Bad Request - Client sent invalid parameters
    rescue_from ActionController::ParameterMissing do |exception|
      render_parameter_missing(exception)
    end

    # 404 Not Found - Resource doesn't exist
    rescue_from ActiveRecord::RecordNotFound do |_exception|
      render_not_found
    end

    # 400 Bad Request - Pagination page out of range
    rescue_from Pagy::RangeError do |exception|
      render_page_out_of_range(exception)
    end

    # 422 Unprocessable Content - Failed authenticity (CSRF) check. The
    # inherited handler negotiates on Accept, so Accept: */* (curl's
    # default) or no Accept header would match its HTML branch and get a
    # flash and a redirect. Rails has already logged the failure.
    rescue_from ActionController::InvalidAuthenticityToken do |_exception|
      render_invalid_authenticity_token
    end

    # 403 Forbidden - Authenticated but not authorized. Same rich body as
    # the HTML controllers' JSON branch (who-to-ask contacts included) —
    # this rescue exists only to skip format negotiation, never to serve a
    # thinner payload. Honors the disclosure policy: a denial on a
    # non-discoverable project conceals as 404 identical to a true miss.
    # Note: 401 Unauthorized is for unauthenticated requests (handled above)
    rescue_from NotAuthorizedError do |exception|
      render_authorization_denied_json(exception)
    end

    private

    # API responses never render the HTML layout, so its callbacks never run
    # here, even for a browser that opens an /api/* URL with Accept: text/html.
    def layout_request?
      false
    end
  end
end
