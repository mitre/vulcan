# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '0_settings.rb initializer consistency' do
  # The initializer (config/initializers/0_settings.rb) provides nil-fallback
  # defaults as a safety net when vulcan.default.yml produces nil values.
  #
  # REQUIREMENT: These fallbacks MUST match the effective defaults in the YAML.
  # If someone changes a default in the YAML but forgets the initializer (or
  # vice versa), the system behaves differently depending on whether the YAML
  # parse succeeded — a subtle, hard-to-debug inconsistency.

  include ConfigFileHelpers

  let(:initializer) { Rails.root.join('config/initializers/0_settings.rb').read }

  describe 'nil-fallback values match YAML effective defaults' do
    # Core features: YAML uses `!= false` → true when unset
    # Initializer should also default to true

    it 'local_login.enabled fallback is true (matching YAML != false pattern)' do
      expect(initializer).to match(/local_login\['enabled'\]\s*=\s*true\s+if/)
    end

    it 'user_registration.enabled fallback is true (matching YAML != false pattern)' do
      expect(initializer).to match(/user_registration\['enabled'\]\s*=\s*true\s+if/)
    end

    it 'project.create_permission_enabled fallback is true (matching YAML != false pattern)' do
      expect(initializer).to match(/project\['create_permission_enabled'\]\s*=\s*true\s+if/)
    end

    it 'oidc.discovery fallback is true (matching YAML != false pattern)' do
      expect(initializer).to match(/oidc\['discovery'\]\s*=\s*true\s+if/)
    end

    # Opt-in services: YAML uses `|| false` → false when unset
    # Initializer should also default to false

    it 'ldap.enabled fallback is false (matching YAML || false pattern)' do
      expect(initializer).to match(/ldap\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'oidc.enabled fallback is false (matching YAML || false pattern)' do
      expect(initializer).to match(/oidc\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'smtp.enabled fallback is false (matching YAML || false pattern)' do
      expect(initializer).to match(/smtp\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'banner.enabled fallback is false (matching YAML || false pattern)' do
      expect(initializer).to match(/banner\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'consent.enabled fallback is false (matching YAML || false pattern)' do
      expect(initializer).to match(/consent\['enabled'\]\s*=\s*false\s+if/)
    end

    it 'slack.enabled fallback is false (matching YAML || false pattern)' do
      expect(initializer).to match(/slack\['enabled'\]\s*=\s*false\s+if/)
    end
  end

  describe 'lockout defaults match YAML' do
    it 'lockout.enabled fallback is true' do
      expect(initializer).to match(/lockout\['enabled'\]\s*=\s*true\s+if/)
    end

    it 'lockout.maximum_attempts fallback is 3' do
      expect(initializer).to match(/lockout\['maximum_attempts'\]\s*=\s*3\s+if/)
    end

    it 'lockout.unlock_in_minutes fallback is 15' do
      expect(initializer).to match(/lockout\['unlock_in_minutes'\]\s*=\s*15\s+if/)
    end
  end

  describe 'password policy defaults match YAML' do
    it 'min_length fallback is 15' do
      expect(initializer).to match(/password\['min_length'\]\s*=\s*15\s+if/)
    end

    it 'min_uppercase fallback is 2' do
      expect(initializer).to match(/password\['min_uppercase'\]\s*=\s*2\s+if/)
    end

    it 'min_lowercase fallback is 2' do
      expect(initializer).to match(/password\['min_lowercase'\]\s*=\s*2\s+if/)
    end

    it 'min_number fallback is 2' do
      expect(initializer).to match(/password\['min_number'\]\s*=\s*2\s+if/)
    end

    it 'min_special fallback is 2' do
      expect(initializer).to match(/password\['min_special'\]\s*=\s*2\s+if/)
    end
  end
end
