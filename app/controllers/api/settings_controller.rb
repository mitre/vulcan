# frozen_string_literal: true

module Api
  # Public pre-auth settings for SPA login page, consent banner, and route guards.
  class SettingsController < BaseController
    skip_before_action :authenticate_user!

    def show
      render json: public_settings
    end

    private

    def public_settings
      {
        banner: {
          enabled: Settings.banner.enabled,
          text: Settings.banner.text,
          background_color: Settings.banner.background_color,
          text_color: Settings.banner.text_color
        },
        consent: {
          enabled: Settings.consent.enabled,
          version: Settings.consent.version,
          title: Settings.consent.title,
          content: Settings.consent.content,
          ttl: Settings.consent.ttl
        },
        local_login: {
          enabled: Settings.local_login.enabled
        },
        user_registration: {
          enabled: Settings.user_registration.enabled
        },
        ldap: {
          enabled: Settings.ldap.enabled,
          title: Settings.ldap.enabled ? Settings.ldap.servers.main.title : nil
        },
        oidc: {
          enabled: Settings.oidc.enabled,
          title: Settings.oidc.enabled ? Settings.oidc.title : nil
        },
        smtp: {
          enabled: Settings.smtp.enabled
        },
        password: {
          min_length: Settings.password.min_length,
          min_uppercase: Settings.password.min_uppercase,
          min_lowercase: Settings.password.min_lowercase,
          min_number: Settings.password.min_number,
          min_special: Settings.password.min_special
        },
        lockout: {
          enabled: Settings.lockout.enabled,
          maximum_attempts: Settings.lockout.maximum_attempts,
          last_attempt_warning: Settings.lockout.last_attempt_warning
        }
      }
    end
  end
end
