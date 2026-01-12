# frozen_string_literal: true

module Admin
  # Admin controller for viewing system settings.
  # Read-only view of current configuration (no secrets exposed).
  class SettingsController < BaseController
    # GET /admin/settings
    def index
      respond_to do |format|
        format.html # renders SPA layout
        format.json { render json: settings_json }
      end
    end

    private

    def settings_json
      {
        authentication: {
          local_login: {
            enabled: Settings.local_login.enabled,
            email_confirmation: Settings.local_login.email_confirmation,
            session_timeout_minutes: Settings.local_login.session_timeout
          },
          user_registration: {
            enabled: Settings.user_registration.enabled
          },
          lockable: {
            enabled: Settings.lockable.enabled,
            max_attempts: Settings.lockable.max_attempts,
            unlock_in_minutes: Settings.lockable.unlock_in_minutes
          }
        },
        ldap: {
          enabled: Settings.ldap.enabled,
          title: Settings.ldap.enabled ? Settings.ldap.servers.main.title : nil
        },
        oidc: {
          enabled: Settings.oidc.enabled,
          title: Settings.oidc.enabled ? Settings.oidc.title : nil,
          issuer: Settings.oidc.enabled ? Settings.oidc.args.issuer : nil
        },
        smtp: {
          enabled: Settings.smtp.enabled,
          address: Settings.smtp.enabled ? Settings.smtp.settings.address : nil,
          port: Settings.smtp.enabled ? Settings.smtp.settings.port : nil
        },
        slack: {
          enabled: Settings.slack.enabled
        },
        project: {
          create_permission_enabled: Settings.project.create_permission_enabled
        },
        app: {
          url: Settings.app_url,
          contact_email: Settings.contact_email
        },
        banner: {
          enabled: Settings.banner.enabled,
          text: Settings.banner.text,
          background_color: Settings.banner.background_color,
          text_color: Settings.banner.text_color
        }
      }
    end
  end
end
