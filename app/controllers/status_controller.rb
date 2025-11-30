# frozen_string_literal: true

# Application status endpoint for deployment verification and monitoring
class StatusController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    render json: {
      application: application_info,
      health: health_status,
      setup: setup_status,
      system: system_status
    }
  end

  private

  def application_info
    {
      name: 'Vulcan',
      version: Rails.application.version.to_s,
      rails_version: Rails.version,
      environment: Rails.application.env.to_s
    }
  end

  def health_status
    {
      status: 'healthy',
      database: database_check,
      ldap: ldap_check,
      oidc: oidc_check
    }
  end

  def setup_status
    {
      admin_user_exists: admin_user_check,
      smtp_configured: Settings.smtp&.enabled || false,
      auth_providers: enabled_auth_providers,
      features: {
        user_registration: Settings.user_registration&.enabled || false,
        project_creation: Settings.project&.create_permission_enabled || false,
        local_login: Settings.local_login&.enabled || false
      }
    }
  end

  def admin_user_check
    User.exists?(admin: true)
  rescue ActiveRecord::StatementInvalid
    false # Table doesn't exist yet
  end

  def system_status
    {
      uptime_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i,
      database_pool_size: ActiveRecord::Base.connection_pool.size,
      database_connections: ActiveRecord::Base.connection_pool.connections.count
    }
  end

  def database_check
    ActiveRecord::Base.connection.execute('SELECT 1')
    'connected'
  rescue StandardError
    'disconnected'
  end

  def ldap_check
    return 'disabled' unless Settings.ldap&.enabled

    'configured'
  end

  def oidc_check
    return 'disabled' unless Settings.oidc&.enabled

    'configured'
  end

  def enabled_auth_providers
    providers = []
    providers << 'local' if Settings.local_login&.enabled
    providers << 'ldap' if Settings.ldap&.enabled
    providers << 'oidc' if Settings.oidc&.enabled
    providers
  end
end
