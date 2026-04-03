# frozen_string_literal: true

module Api
  ##
  # Public endpoint for application version and metadata.
  # No authentication required — used by monitoring tools,
  # deployment verification scripts, and the frontend.
  #
  # GET /api/version
  #
  class VersionController < BaseController
    skip_before_action :authenticate_user!
    skip_before_action :check_locked_user_notifications

    def show
      render json: {
        name: 'Vulcan',
        version: Vulcan::VERSION,
        rails: Rails.version,
        ruby: RUBY_VERSION,
        environment: Rails.env
      }
    end
  end
end
