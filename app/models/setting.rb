# frozen_string_literal: true

# RailsSettings Model
class Setting < RailsSettings::Base
  cache_prefix { 'v1' }

  # Authentication Settings Group
  scope :local_login do
    field :local_login_enabled, type: :boolean, default: -> { ENV['VULCAN_ENABLE_LOCAL_LOGIN'] != 'false' }
    field :local_login_session_timeout, type: :integer, default: -> { ENV['VULCAN_SESSION_TIMEOUT']&.to_i || 60 }
    field :local_login_email_confirmation, type: :boolean, default: lambda {
                                                                      ENV['VULCAN_ENABLE_EMAIL_CONFIRMATION'] == 'true'
                                                                    }
  end

  scope :oidc do
    field :oidc_enabled, type: :boolean, default: -> { ENV['VULCAN_ENABLE_OIDC'] == 'true' }
    field :oidc_discovery, type: :boolean, default: -> { ENV['VULCAN_OIDC_DISCOVERY'] != 'false' }
    field :oidc_strategy, type: :string, default: 'openid_connect'
    field :oidc_title, type: :string, default: -> { ENV['VULCAN_OIDC_PROVIDER_TITLE'] || 'Single Sign-On' }
    field :oidc_args, type: :hash, default: {}
  end

  scope :ldap do
    field :ldap_enabled, type: :boolean, default: -> { ENV['VULCAN_ENABLE_LDAP'] == 'true' }
    field :ldap_servers, type: :hash, default: {}
  end

  scope :smtp do
    field :smtp_enabled, type: :boolean, default: -> { ENV['VULCAN_ENABLE_SMTP'] == 'true' }
    field :smtp_settings, type: :hash, default: {}
  end

  scope :slack do
    field :slack_enabled, type: :boolean, default: -> { ENV['VULCAN_ENABLE_SLACK_COMMS'] == 'true' }
    field :slack_api_token, type: :string, default: -> { ENV['VULCAN_SLACK_API_TOKEN'] }
    field :slack_channel_id, type: :string, default: -> { ENV['VULCAN_SLACK_CHANNEL_ID'] }
  end

  scope :project do
    field :project_create_permission_enabled, type: :boolean, default: lambda {
      ENV['VULCAN_PROJECT_CREATE_PERMISSION_ENABLED'] != 'false'
    }
  end

  scope :user_registration do
    field :user_registration_enabled, type: :boolean, default: -> { ENV['VULCAN_ENABLE_USER_REGISTRATION'] != 'false' }
  end

  # Simple top-level settings
  field :contact_email, type: :string, default: -> { ENV['VULCAN_CONTACT_EMAIL'] || 'admin@vulcan.local' }
  field :app_url, type: :string, default: -> { ENV['VULCAN_APP_URL'] }
  field :welcome_text, type: :string, default: -> { ENV['VULCAN_WELCOME_TEXT'] }
  field :providers, type: :array, default: []
end
