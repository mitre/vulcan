# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings defaults' do
  # These tests verify the FINAL state of Settings after both:
  #   1. config/vulcan.default.yml (YAML with ERB) is loaded
  #   2. config/initializers/0_settings.rb fills in nil values
  #
  # Settings are loaded ONCE during Rails boot. The YAML uses two patterns:
  #   - `!= false` → defaults to true (core features)
  #   - `|| false` → defaults to false (opt-in services)
  #
  # The initializer then fills in any remaining nil values as a safety net.
  #
  # Some values may be overridden by .env file in local development.
  # Tests check the env var state and validate the correct resulting value.

  describe 'core functionality defaults to true when env vars are unset' do
    # YAML pattern: `ActiveModel::Type::Boolean.new.cast(ENV['...']) != false`
    # When env var is unset: cast(nil) => nil, nil != false => true

    it 'local_login is enabled' do
      expect(Settings.local_login['enabled']).to be true
    end

    it 'user_registration is enabled' do
      expect(Settings.user_registration['enabled']).to be true
    end

    it 'project create_permission_enabled is true' do
      expect(Settings.project['create_permission_enabled']).to be true
    end

    it 'first_user_admin is enabled' do
      expect(Settings.admin_bootstrap['first_user_admin']).to be true
    end
  end

  describe 'opt-in services default to false when env vars are unset' do
    # YAML pattern: `ActiveModel::Type::Boolean.new.cast(ENV['...']) || false`
    # When env var is unset: cast(nil) => nil, nil || false => false
    # Initializer backup: sets false if value is nil

    it 'ldap is disabled by default' do
      skip 'VULCAN_ENABLE_LDAP is set in environment' if ENV.fetch('VULCAN_ENABLE_LDAP', nil).present?
      expect(Settings.ldap['enabled']).to be false
    end

    it 'oidc is disabled by default' do
      skip 'VULCAN_ENABLE_OIDC is set in environment' if ENV.fetch('VULCAN_ENABLE_OIDC', nil).present?
      expect(Settings.oidc['enabled']).to be false
    end

    it 'smtp is disabled by default' do
      skip 'VULCAN_ENABLE_SMTP is set in environment' if ENV.fetch('VULCAN_ENABLE_SMTP', nil).present?
      expect(Settings.smtp['enabled']).to be false
    end

    it 'slack is disabled by default' do
      skip 'VULCAN_ENABLE_SLACK_COMMS is set in environment' if ENV.fetch('VULCAN_ENABLE_SLACK_COMMS', nil).present?
      expect(Settings.slack['enabled']).to be false
    end
  end

  describe 'OIDC discovery defaults to true' do
    # YAML pattern: `ActiveModel::Type::Boolean.new.cast(ENV['...']) || true`
    # When env var is unset: cast(nil) => nil, nil || true => true
    # Initializer backup: sets true if value is nil

    it 'discovery is enabled' do
      expect(Settings.oidc['discovery']).to be true
    end
  end

  describe 'contact email fallback' do
    # Initializer: sets 'vulcan-support@example.com' if contact_email is blank
    # YAML: reads ENV.fetch('VULCAN_CONTACT_EMAIL', nil) (nil when unset)

    it 'has a non-blank contact email' do
      expect(Settings['contact_email']).to be_present
    end

    it 'uses vulcan-support@example.com when VULCAN_CONTACT_EMAIL is unset' do
      if ENV.fetch('VULCAN_CONTACT_EMAIL', nil).present?
        expect(Settings['contact_email']).to eq(ENV.fetch('VULCAN_CONTACT_EMAIL', nil))
      else
        expect(Settings['contact_email']).to eq('vulcan-support@example.com')
      end
    end
  end

  describe 'initializer ensures all settings sections exist' do
    # The initializer uses `||= Settingslogic.new({})` to guarantee
    # each section exists even if the YAML is missing it entirely.

    it 'ldap section exists' do
      expect(Settings['ldap']).not_to be_nil
    end

    it 'oidc section exists' do
      expect(Settings['oidc']).not_to be_nil
    end

    it 'local_login section exists' do
      expect(Settings['local_login']).not_to be_nil
    end

    it 'user_registration section exists' do
      expect(Settings['user_registration']).not_to be_nil
    end

    it 'project section exists' do
      expect(Settings['project']).not_to be_nil
    end

    it 'smtp section exists' do
      expect(Settings['smtp']).not_to be_nil
    end

    it 'slack section exists' do
      expect(Settings['slack']).not_to be_nil
    end

    it 'providers section exists' do
      expect(Settings['providers']).not_to be_nil
    end
  end
end
