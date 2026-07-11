# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings.apply_defaults! consistency' do
  # Settings.apply_defaults! (config/settings.rb) provides nil-fallback
  # defaults as a safety net when vulcan.default.yml produces nil values.
  # It runs at boot (via config/initializers/0_settings.rb) and again on
  # every Settings.reload!.
  #
  # REQUIREMENT: These fallbacks MUST match the effective defaults in the
  # YAML. If someone changes a default in the YAML but forgets apply_defaults!
  # (or vice versa), the system behaves differently depending on whether the
  # YAML parse produced a value — a subtle, hard-to-debug inconsistency.

  include ConfigFileHelpers

  # The fallbacks live on the Settings class as `self['section']['key'] = X`.
  let(:defaults_source) { Rails.root.join('config/settings.rb').read }

  describe 'nil-fallback values match YAML effective defaults' do
    # Core features: YAML uses `!= false` → true when unset
    # apply_defaults! should also default to true

    it 'local_login.enabled fallback is true (matching YAML != false pattern)' do
      expect(defaults_source).to match(/local_login'\]\['enabled'\]\s*=\s*true\s+if/)
    end

    it 'user_registration.enabled fallback is true (matching YAML != false pattern)' do
      expect(defaults_source).to match(/user_registration'\]\['enabled'\]\s*=\s*true\s+if/)
    end

    it 'project.create_permission_enabled fallback is true (matching YAML != false pattern)' do
      expect(defaults_source).to match(/project'\]\['create_permission_enabled'\]\s*=\s*true\s+if/)
    end

    it 'oidc.discovery fallback is true (matching YAML != false pattern)' do
      expect(defaults_source).to match(/oidc'\]\['discovery'\]\s*=\s*true\s+if/)
    end

    # Opt-in services: YAML uses `|| false` → false when unset
    # apply_defaults! should also default to false

    it 'ldap.enabled fallback is false (matching YAML || false pattern)' do
      expect(defaults_source).to match(/ldap'\]\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'oidc.enabled fallback is false (matching YAML || false pattern)' do
      expect(defaults_source).to match(/oidc'\]\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'smtp.enabled fallback is false (matching YAML || false pattern)' do
      expect(defaults_source).to match(/smtp'\]\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'banner.enabled fallback is false (matching YAML || false pattern)' do
      expect(defaults_source).to match(/banner'\]\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'consent.enabled fallback is false (matching YAML || false pattern)' do
      expect(defaults_source).to match(/consent'\]\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'slack.enabled fallback is false (matching YAML || false pattern)' do
      expect(defaults_source).to match(/slack'\]\['enabled'\]\s*=\s*false\s+if/)
    end
  end

  describe 'lockout defaults match YAML' do
    it 'lockout.enabled fallback is true' do
      expect(defaults_source).to match(/lockout'\]\['enabled'\]\s*=\s*true\s+if/)
    end

    it 'lockout.maximum_attempts fallback is 3' do
      expect(defaults_source).to match(/lockout'\]\['maximum_attempts'\]\s*=\s*3\s+if/)
    end

    it 'lockout.unlock_in_minutes fallback is 15' do
      expect(defaults_source).to match(/lockout'\]\['unlock_in_minutes'\]\s*=\s*15\s+if/)
    end
  end

  describe 'password policy defaults match YAML' do
    it 'min_length fallback is 15' do
      expect(defaults_source).to match(/password'\]\['min_length'\]\s*=\s*15\s+if/)
    end

    it 'min_uppercase fallback is 2' do
      expect(defaults_source).to match(/password'\]\['min_uppercase'\]\s*=\s*2\s+if/)
    end

    it 'min_lowercase fallback is 2' do
      expect(defaults_source).to match(/password'\]\['min_lowercase'\]\s*=\s*2\s+if/)
    end

    it 'min_number fallback is 2' do
      expect(defaults_source).to match(/password'\]\['min_number'\]\s*=\s*2\s+if/)
    end

    it 'min_special fallback is 2' do
      expect(defaults_source).to match(/password'\]\['min_special'\]\s*=\s*2\s+if/)
    end
  end
end
