# frozen_string_literal: true

# Optional migration to import settings from old YAML files if they exist
# This helps smooth the upgrade process for existing installations
class MigrateYamlSettingsToDatabase < ActiveRecord::Migration[6.1]
  def up
    # Only run if upgrading from an old version with YAML config
    yaml_file = Rails.root.join('config', 'vulcan.default.yml')

    if File.exist?(yaml_file)
      say_with_time 'Importing settings from vulcan.default.yml' do
        # Load the YAML file
        config = YAML.load_file(yaml_file)
        env_config = config[Rails.env] || config['defaults'] || {}

        # Import settings that don't have environment variable overrides
        import_setting('welcome_text', env_config['welcome_text']) if ENV['VULCAN_WELCOME_TEXT'].blank?
        import_setting('contact_email', env_config['contact_email']) if ENV['VULCAN_CONTACT_EMAIL'].blank?

        # NOTE: We don't import sensitive settings like OIDC/LDAP credentials
        # Those should come from environment variables

        say "Settings imported. Review with: rails runner 'Setting.all.each { |s| puts s.var }'"
      rescue StandardError => e
        say "Warning: Could not import YAML settings: #{e.message}", true
        say 'Please configure settings manually via environment variables or Rails console', true
      end
    else
      say 'No vulcan.default.yml found - skipping import'
    end
  end

  def down
    # No rollback needed - settings remain in database
  end

  private

  def import_setting(key, value)
    return if value.blank?

    # Use the new flattened naming convention
    setting_key = key.to_s

    # Check if already set
    existing = Setting.find_by(var: setting_key)
    if existing
      say "  #{setting_key}: already set, skipping"
    else
      Setting.public_send("#{setting_key}=", value)
      say "  #{setting_key}: imported"
    end
  rescue StandardError => e
    say "  #{setting_key}: failed to import - #{e.message}", true
  end
end