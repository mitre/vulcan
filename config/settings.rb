# frozen_string_literal: true

# Compatibility layer to provide Settings.* nested API using rails-settings-cached
# This bridges the gap between the old settingslogic API and the new flat field structure

# Provides backward-compatible Settings.* API for rails-settings-cached migration
class Settings
  # Local Login Settings
  class << self
    def local_login
      @local_login ||= LocalLogin.new
    end

    def oidc
      @oidc ||= Oidc.new
    end

    def ldap
      @ldap ||= Ldap.new
    end

    def smtp
      @smtp ||= Smtp.new
    end

    def slack
      @slack ||= Slack.new
    end

    def project
      @project ||= Project.new
    end

    def user_registration
      @user_registration ||= UserRegistration.new
    end

    # Simple top-level settings
    def contact_email
      Setting.contact_email
    end

    def contact_email=(value)
      Setting.contact_email = value
    end

    def app_url
      Setting.app_url
    end

    def app_url=(value)
      Setting.app_url = value
    end

    def welcome_text
      Setting.welcome_text
    end

    def welcome_text=(value)
      Setting.welcome_text = value
    end

    def providers
      Setting.providers
    end

    def providers=(value)
      Setting.providers = value
    end
  end

  # Nested setting classes that delegate to the flat Setting model
  # Handles local login configuration settings
  class LocalLogin
    def enabled
      Setting.local_login_enabled
    end

    def enabled=(value)
      Setting.local_login_enabled = value
    end

    def session_timeout
      Setting.local_login_session_timeout
    end

    def session_timeout=(value)
      Setting.local_login_session_timeout = value
    end

    def email_confirmation
      Setting.local_login_email_confirmation
    end

    def email_confirmation=(value)
      Setting.local_login_email_confirmation = value
    end
  end

  # Handles OIDC configuration settings
  class Oidc
    def enabled
      Setting.oidc_enabled
    end

    def enabled=(value)
      Setting.oidc_enabled = value
    end

    def discovery
      Setting.oidc_discovery
    end

    def discovery=(value)
      Setting.oidc_discovery = value
    end

    def strategy
      Setting.oidc_strategy
    end

    def strategy=(value)
      Setting.oidc_strategy = value
    end

    def title
      Setting.oidc_title
    end

    def title=(value)
      Setting.oidc_title = value
    end

    def args
      Setting.oidc_args
    end

    def args=(value)
      Setting.oidc_args = value
    end
  end

  # Handles LDAP configuration settings
  class Ldap
    def enabled
      Setting.ldap_enabled
    end

    def enabled=(value)
      Setting.ldap_enabled = value
    end

    def servers
      Setting.ldap_servers
    end

    def servers=(value)
      Setting.ldap_servers = value
    end
  end

  # Handles SMTP configuration settings
  class Smtp
    def enabled
      Setting.smtp_enabled
    end

    def enabled=(value)
      Setting.smtp_enabled = value
    end

    def settings
      Setting.smtp_settings
    end

    def settings=(value)
      Setting.smtp_settings = value
    end
  end

  # Handles Slack integration settings
  class Slack
    def enabled
      Setting.slack_enabled
    end

    def enabled=(value)
      Setting.slack_enabled = value
    end

    def api_token
      Setting.slack_api_token
    end

    def api_token=(value)
      Setting.slack_api_token = value
    end

    def channel_id
      Setting.slack_channel_id
    end

    def channel_id=(value)
      Setting.slack_channel_id = value
    end
  end

  # Handles project configuration settings
  class Project
    def create_permission_enabled
      Setting.project_create_permission_enabled
    end

    def create_permission_enabled=(value)
      Setting.project_create_permission_enabled = value
    end
  end

  # Handles user registration settings
  class UserRegistration
    def enabled
      Setting.user_registration_enabled
    end

    def enabled=(value)
      Setting.user_registration_enabled = value
    end
  end
end
