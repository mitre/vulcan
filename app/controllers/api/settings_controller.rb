# frozen_string_literal: true

module Api
  ##
  # API controller for public application settings
  # Returns configuration that doesn't require authentication
  #
  class SettingsController < ActionController::API
    ##
    # GET /api/settings/consent_banner
    # Returns consent banner configuration
    #
    def consent_banner
      render json: {
        enabled: Settings.consent_banner&.enabled || false,
        version: Settings.consent_banner&.version || 1,
        content: Settings.consent_banner&.content || ''
      }
    end
  end
end
