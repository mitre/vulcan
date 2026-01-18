# frozen_string_literal: true

module Api
  ##
  # API controller for public application settings
  # Returns configuration that doesn't require authentication
  #
  class SettingsController < ActionController::API
    ##
    # GET /api/settings
    # Returns all public UI settings (consolidated endpoint)
    #
    def index
      render json: {
        banners: {
          app: banner_app_settings,
          consent: banner_consent_settings
        }
      }
    end

    ##
    # GET /api/settings/consent_banner
    # Returns consent banner configuration (legacy endpoint)
    # @deprecated Use GET /api/settings instead
    #
    def consent_banner
      render json: banner_consent_settings
    end

    private

    def banner_app_settings
      {
        enabled: Settings.banner_app&.enabled || false,
        text: Settings.banner_app&.text || '',
        backgroundColor: Settings.banner_app&.background_color || '#198754',
        textColor: Settings.banner_app&.text_color || '#ffffff'
      }
    end

    def banner_consent_settings
      {
        enabled: Settings.banner_consent&.enabled || false,
        version: Settings.banner_consent&.version || 1,
        title: Settings.banner_consent&.title || 'Terms of Use',
        titleAlign: Settings.banner_consent&.title_align || 'center',
        # ENV override for container/k8s deployments (12-factor pattern)
        content: ENV['VULCAN_CONSENT_BANNER_CONTENT'] || Settings.banner_consent&.content || ''
      }
    end
  end
end
