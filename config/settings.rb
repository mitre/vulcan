# frozen_string_literal: true

require 'settingslogic'
require_relative '../lib/oidc_provider_registry'

# Load settings that are used globally throughout the application.
# We load settings from a file in order to allow the most flexability
# across deployment types. Since SettingsLogic does ERB parsing, we
# are also able to load some basic settings using environment variables.
# For a full list of settings that can be applied using environment
# variables, check vulcan.default.yml.
#
# Note, once you create a vulcan.yml, environment variable parsing
# will no longer work unless you include the `ENV` declarations in
# your copy of vulcan.yml as well.
#
class Settings < Settingslogic
  class << self
    def find_config
      # There are 2 locations that we check for config files,
      # either we check the default location or we check if
      # the user has created a vulcan.yml
      ['vulcan.yml', 'vulcan.default.yml'].each do |config|
        path = get_full_path_for(config)
        return path if path.exist?
      end

      nil # Neither config file exists, this should never happen
    end

    def get_full_path_for(config_file)
      Pathname.new(File.expand_path('..', __dir__)).join("config/#{config_file}")
    end

    # Settingslogic#reload! rebuilds the instance straight from the YAML,
    # which renders several values nil when their env vars are unset (no
    # `|| false` on smtp.enabled, no top-level oidc.discovery key, unquoted
    # `#rrggbb` color defaults that YAML parses as comments). Those values
    # exist only via apply_defaults!, and initializers run once per boot —
    # so every reload must re-apply them or the process is left with nil
    # sections until restart.
    def reload!
      super.tap { apply_defaults! }
    end

    # Backfill sections and defaults the YAML cannot express. Idempotent:
    # every assignment is guarded, so boot (via the 0_settings initializer)
    # and every reload! can call it safely.
    def apply_defaults!
      self['ldap'] ||= Settingslogic.new({})
      self['ldap']['enabled'] = false if self['ldap']['enabled'].nil?

      self['oidc'] ||= Settingslogic.new({})
      self['oidc']['enabled'] = false if self['oidc']['enabled'].nil?
      self['oidc']['discovery'] = true if self['oidc']['discovery'].nil?

      self['local_login'] ||= Settingslogic.new({})
      self['local_login']['enabled'] = true if self['local_login']['enabled'].nil?

      self['user_registration'] ||= Settingslogic.new({})
      self['user_registration']['enabled'] = true if self['user_registration']['enabled'].nil?

      self['project'] ||= Settingslogic.new({})
      self['project']['create_permission_enabled'] = true if self['project']['create_permission_enabled'].nil?

      self['smtp'] ||= Settingslogic.new({})
      self['smtp']['enabled'] = false if self['smtp']['enabled'].nil?

      self['banner'] ||= Settingslogic.new({})
      self['banner']['enabled'] = false if self['banner']['enabled'].nil?
      self['banner']['text'] = '' if self['banner']['text'].nil?
      self['banner']['background_color'] = '#007a33' if self['banner']['background_color'].blank?
      self['banner']['text_color'] = '#ffffff' if self['banner']['text_color'].blank?

      self['consent'] ||= Settingslogic.new({})
      self['consent']['enabled'] = false if self['consent']['enabled'].nil?
      self['consent']['version'] = '1' if self['consent']['version'].blank?
      self['consent']['title'] = 'Terms of Use' if self['consent']['title'].blank?
      self['consent']['content'] = '' if self['consent']['content'].nil?

      self['lockout'] ||= Settingslogic.new({})
      self['lockout']['enabled'] = true if self['lockout']['enabled'].nil?
      self['lockout']['maximum_attempts'] = 3 if self['lockout']['maximum_attempts'].nil?
      self['lockout']['unlock_in_minutes'] = 15 if self['lockout']['unlock_in_minutes'].nil?
      self['lockout']['unlock_strategy'] = 'both' if self['lockout']['unlock_strategy'].blank?
      self['lockout']['last_attempt_warning'] = true if self['lockout']['last_attempt_warning'].nil?

      self['password'] ||= Settingslogic.new({})
      self['password']['min_length'] = 15 if self['password']['min_length'].nil?
      self['password']['min_uppercase'] = 2 if self['password']['min_uppercase'].nil?
      self['password']['min_lowercase'] = 2 if self['password']['min_lowercase'].nil?
      self['password']['min_number'] = 2 if self['password']['min_number'].nil?
      self['password']['min_special'] = 2 if self['password']['min_special'].nil?

      self['slack'] ||= Settingslogic.new({})
      self['slack']['enabled'] = false if self['slack']['enabled'].nil?

      self['providers'] ||= Settingslogic.new({})

      self['contact_email'] = 'vulcan-support@example.com' if self['contact_email'].blank?
    end
  end

  source ENV.fetch('VULCAN_CONFIG') { find_config }
  namespace ENV.fetch('VULCAN_ENV') { Rails.env }
end
