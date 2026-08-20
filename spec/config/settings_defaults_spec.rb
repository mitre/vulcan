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

  describe 'opt-in services default to false when their env vars are unset' do
    # YAML pattern: `ActiveModel::Type::Boolean.new.cast(ENV['...']) || false`
    # → false when the env var is unset.
    #
    # Asserted deterministically: with_settings_env unsets the controlling env
    # var and reloads Settings, so the assertion RUNS regardless of the dev/CI
    # environment (and restores Settings afterward). No skip-guards — a test
    # that passes by skipping asserts nothing.
    {
      'ldap' => :VULCAN_ENABLE_LDAP,
      'oidc' => :VULCAN_ENABLE_OIDC,
      'smtp' => :VULCAN_ENABLE_SMTP,
      'slack' => :VULCAN_ENABLE_SLACK_COMMS,
      'banner' => :VULCAN_BANNER_ENABLED,
      'consent' => :VULCAN_CONSENT_ENABLED
    }.each do |section, env_var|
      it "#{section} is disabled by default" do
        with_settings_env(env_var => nil) do
          expect(Settings[section]['enabled']).to be false
        end
      end
    end
  end

  describe 'password policy defaults to its documented values when env vars are unset' do
    # YAML pattern: `ENV.fetch('VULCAN_PASSWORD_MIN_*', '<n>').to_i`.
    # Asserted deterministically via with_settings_env so a locally-set
    # VULCAN_PASSWORD_MIN_* cannot mask the default value.
    {
      'min_length' => [15, :VULCAN_PASSWORD_MIN_LENGTH],
      'min_uppercase' => [2, :VULCAN_PASSWORD_MIN_UPPERCASE],
      'min_lowercase' => [2, :VULCAN_PASSWORD_MIN_LOWERCASE],
      'min_number' => [2, :VULCAN_PASSWORD_MIN_NUMBER],
      'min_special' => [2, :VULCAN_PASSWORD_MIN_SPECIAL]
    }.each do |key, (value, env_var)|
      it "password.#{key} defaults to #{value}" do
        with_settings_env(env_var => nil) do
          expect(Settings.password[key]).to eq(value)
        end
      end
    end
  end

  describe 'OIDC discovery defaults to true' do
    # YAML pattern: `ActiveModel::Type::Boolean.new.cast(ENV['...']) != false`
    # When env var is unset: cast(nil) => nil, nil != false => true
    # Initializer backup: sets true if value is nil

    it 'discovery is enabled' do
      expect(Settings.oidc['discovery']).to be true
    end

    it 'discovery setting is only inside args (not duplicated at section level)' do
      # Parse the YAML (with ERB) and check structure semantically
      erb_rendered = ERB.new(Rails.root.join('config/vulcan.default.yml').read).result
      yaml = YAML.safe_load(erb_rendered, permitted_classes: [Symbol, Proc], aliases: true)
      oidc = yaml.dig('defaults', 'oidc')

      expect(oidc.keys).not_to include('discovery'),
                               'oidc section should not have a top-level discovery key (it belongs in oidc.args)'
    end
  end

  describe 'terminology defaults when env vars are unset' do
    # YAML pattern: `ENV.fetch('VULCAN_TERM_*', '<default>').to_json`, with
    # blank-hardening in Settings.apply_defaults! following the banner block.
    # Deployments rename the entity noun per kind (e.g. Requirement → Control);
    # unset and blank env vars both resolve to the built-in defaults.
    let(:unset_terminology_env) do
      {
        VULCAN_TERM_STIG_SINGULAR: nil, VULCAN_TERM_STIG_PLURAL: nil, VULCAN_TERM_STIG_LABEL: nil,
        VULCAN_TERM_SRG_SINGULAR: nil, VULCAN_TERM_SRG_PLURAL: nil, VULCAN_TERM_SRG_LABEL: nil
      }
    end

    it 'stig defaults to Rule/Rules/Rule' do
      with_settings_env(**unset_terminology_env) do
        expect(Settings.terminology.stig['singular']).to eq('Rule')
        expect(Settings.terminology.stig['plural']).to eq('Rules')
        expect(Settings.terminology.stig['label']).to eq('Rule')
      end
    end

    it 'srg defaults to Requirement/Requirements/Req' do
      with_settings_env(**unset_terminology_env) do
        expect(Settings.terminology.srg['singular']).to eq('Requirement')
        expect(Settings.terminology.srg['plural']).to eq('Requirements')
        expect(Settings.terminology.srg['label']).to eq('Req')
      end
    end

    it 'an env var overrides its term part' do
      with_settings_env(VULCAN_TERM_SRG_SINGULAR: 'Control', VULCAN_TERM_SRG_PLURAL: 'Controls',
                        VULCAN_TERM_SRG_LABEL: 'Ctrl') do
        expect(Settings.terminology.srg['singular']).to eq('Control')
        expect(Settings.terminology.srg['plural']).to eq('Controls')
        expect(Settings.terminology.srg['label']).to eq('Ctrl')
      end
    end

    it 'a blank env var falls back to the default (apply_defaults! hardening)' do
      with_settings_env(VULCAN_TERM_STIG_SINGULAR: '', VULCAN_TERM_SRG_LABEL: '') do
        expect(Settings.terminology.stig['singular']).to eq('Rule')
        expect(Settings.terminology.srg['label']).to eq('Req')
      end
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

  describe 'numeric settings are Integer, not String' do
    {
      'consent.version' => -> { Settings.consent.version },
      'consent.ttl' => -> { Settings.consent.ttl },
      'password.min_length' => -> { Settings.password.min_length },
      'password.min_uppercase' => -> { Settings.password.min_uppercase },
      'password.min_lowercase' => -> { Settings.password.min_lowercase },
      'password.min_number' => -> { Settings.password.min_number },
      'password.min_special' => -> { Settings.password.min_special },
      'local_login.session_timeout' => -> { Settings.local_login.session_timeout },
      'local_login.remember_me_duration' => -> { Settings.local_login.remember_me_duration },
      'lockout.maximum_attempts' => -> { Settings.lockout.maximum_attempts },
      'lockout.unlock_in_minutes' => -> { Settings.lockout.unlock_in_minutes },
      'session_limits.max_sessions' => -> { Settings.session_limits.max_sessions },
      'input_limits.short_string' => -> { Settings.input_limits.short_string },
      'input_limits.long_text' => -> { Settings.input_limits.long_text },
      'api_tokens.max_tokens_per_user' => -> { Settings.api_tokens.max_tokens_per_user },
      'api_tokens.max_lifetime_days' => -> { Settings.api_tokens.max_lifetime_days },
      'api_tokens.auto_revoke_idle_days' => -> { Settings.api_tokens.auto_revoke_idle_days }
    }.each do |path, accessor|
      it "Settings.#{path} is Integer" do
        value = accessor.call
        expect(value).to be_a(Integer),
                         "Expected Settings.#{path} to be Integer, got #{value.class} (#{value.inspect})"
      end
    end
  end

  describe 'auditing is disabled by default in test environment' do
    it 'Audited.auditing_enabled is false' do
      expect(Audited.auditing_enabled).to be(false)
    end

    it 'factory-created records do NOT generate audit records' do
      expect { create(:project) }.not_to change(Audited::Audit, :count)
    end

    context 'with auditing re-enabled via shared context' do
      include_context 'with auditing'

      it 'Audited.auditing_enabled is true inside the context' do
        expect(Audited.auditing_enabled).to be(true)
      end

      it 'factory-created records DO generate audit records' do
        expect { create(:project) }.to change(Audited::Audit, :count).by(1)
      end
    end

    it 'restores auditing to false after shared context exits' do
      expect(Audited.auditing_enabled).to be(false)
      expect { create(:project) }.not_to change(Audited::Audit, :count)
    end
  end
end
