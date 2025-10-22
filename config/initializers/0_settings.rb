# frozen_string_literal: true

# We load our settings first so that we can access them
# in other initializers

require_relative '../settings'

Settings['ldap'] ||= Settingslogic.new({})
Settings.ldap['enabled'] = false if Settings.ldap['enabled'].nil?

Settings['oidc'] ||= Settingslogic.new({})
Settings.oidc['enabled'] = false if Settings.oidc['enabled'].nil?
Settings.oidc['discovery'] = true if Settings.oidc['discovery'].nil?

Settings['local_login'] ||= Settingslogic.new({})
Settings.local_login['enabled'] = false if Settings.local_login['enabled'].nil?

Settings['user_registration'] ||= Settingslogic.new({})
Settings.user_registration['enabled'] = false if Settings.user_registration['enabled'].nil?

Settings['project'] ||= Settingslogic.new({})
Settings.project['create_permission_enabled'] = false if Settings.project['create_permission_enabled'].nil?

Settings['smtp'] ||= Settingslogic.new({})
Settings.smtp['enabled'] = false if Settings.smtp['enabled'].nil?

Settings['slack'] ||= Settingslogic.new({})
Settings.slack['enabled'] = false if Settings.slack['enabled'].nil?

Settings['providers'] ||= Settingslogic.new({})

# Email configuration with production validation
# Only validate when starting a server (not during rake tasks, console, etc.)
if defined?(Rails::Server) && Rails.env.production?
  # Validate SMTP configuration if enabled
  if Settings.smtp.enabled
    # Check for valid contact email
    if Settings['contact_email'].blank?
      puts <<~TEXT

        ================================ CONFIGURATION ERROR ================================
        VULCAN_CONTACT_EMAIL is required when SMTP is enabled in production.

        This email address will be used as the 'from' address for all system notifications
        including membership invitations, review requests, and access approvals.

        Set this environment variable:
          VULCAN_CONTACT_EMAIL=vulcan-notifications@your-org.com

        =================================================================================

      TEXT
      raise "VULCAN_CONTACT_EMAIL is required when SMTP is enabled"
    end

    # Validate email format using valid_email2 gem
    unless ValidEmail2::Address.new(Settings['contact_email']).valid?
      puts <<~TEXT

        ================================ CONFIGURATION ERROR ================================
        VULCAN_CONTACT_EMAIL has invalid email format.

        Current value: #{Settings['contact_email']}

        Please provide a properly formatted email address.

        Example:
          VULCAN_CONTACT_EMAIL=vulcan-notifications@your-org.com

        =================================================================================

      TEXT
      raise "VULCAN_CONTACT_EMAIL has invalid format"
    end

    # Check for example.com domains (common mistake)
    if Settings['contact_email'].end_with?('@example.com', '@example.org')
      puts <<~TEXT

        ================================ CONFIGURATION ERROR ================================
        VULCAN_CONTACT_EMAIL cannot use an example domain in production.

        Current value: #{Settings['contact_email']}

        Example domains (@example.com, @example.org) will trigger spam filters and
        cause email delivery failures. Use your organization's real email domain.

        Example:
          VULCAN_CONTACT_EMAIL=vulcan-notifications@your-org.com

        =================================================================================

      TEXT
      raise "VULCAN_CONTACT_EMAIL cannot use example domain"
    end

    # Validate required SMTP settings
    required_settings = {
      'address' => 'VULCAN_SMTP_ADDRESS (e.g., smtp.gmail.com)',
      'port' => 'VULCAN_SMTP_PORT (e.g., 587)',
      'domain' => 'VULCAN_SMTP_DOMAIN (e.g., your-org.com)'
    }

    missing = required_settings.select { |key, _| Settings.smtp.settings[key].blank? }

    if missing.any?
      missing_list = missing.map { |key, example| "  - #{example}" }.join("\n")
      puts <<~TEXT

        ================================ CONFIGURATION ERROR ================================
        SMTP is enabled but required settings are missing!

        Missing configuration:
        #{missing_list}

        Complete SMTP configuration example:
          VULCAN_ENABLE_SMTP=true
          VULCAN_CONTACT_EMAIL=vulcan-notifications@your-org.com
          VULCAN_SMTP_ADDRESS=smtp.your-org.com
          VULCAN_SMTP_PORT=587
          VULCAN_SMTP_DOMAIN=your-org.com
          VULCAN_SMTP_AUTHENTICATION=plain
          VULCAN_SMTP_SERVER_USERNAME=smtp-user (optional, defaults to VULCAN_CONTACT_EMAIL)
          VULCAN_SMTP_SERVER_PASSWORD=your-smtp-password

        See documentation: https://vulcan.mitre.org/deployment/configuration
        =================================================================================

      TEXT
      raise "Required SMTP settings are missing"
    end

    # Warn about missing password (common in Kubernetes secrets)
    if Settings.smtp.settings['password'].blank?
      Rails.logger.warn "VULCAN_SMTP_SERVER_PASSWORD is not set. SMTP authentication may fail."
    end
  else
    # SMTP disabled in production - warn about example.com emails and clear them
    if Settings['contact_email'].present? && Settings['contact_email'].end_with?('@example.com', '@example.org')
      Rails.logger.warn "VULCAN_CONTACT_EMAIL uses example domain. Email notifications are disabled."
      Settings['contact_email'] = nil
    end
  end
elsif Rails.env.production?
  # Production but not server startup (rake tasks, console, etc.)
  # Just set safe defaults without validation
  Settings['contact_email'] = nil if Settings['contact_email'].blank? || Settings['contact_email'].end_with?('@example.com', '@example.org')
else
  # Development/test: use safe fallback
  Settings['contact_email'] = 'vulcan-support@example.com' if Settings['contact_email'].blank?
end
