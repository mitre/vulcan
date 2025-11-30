# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings Validation' do
  describe 'email configuration validation' do
    # Capture original values before any test runs
    before(:all) do
      @original_contact_email = Settings.contact_email
      @original_smtp_enabled = Settings.smtp.enabled
    end

    before do
      # Set production environment for validation tests
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    end

    after do
      # Reload Settings to clear any modifications and prevent pollution
      # This is the official Settingslogic way to reset state
      Settings.reload!

      # Reset Rails.env stub
      allow(Rails).to receive(:env).and_call_original
    end

    context 'when SMTP is enabled in production' do
      before do
        Settings.smtp['enabled'] = true
        stub_const('Rails::Server', Class.new)
      end

      it 'requires VULCAN_CONTACT_EMAIL to be set' do
        Settings['contact_email'] = nil

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.to raise_error(RuntimeError, /VULCAN_CONTACT_EMAIL is required/)
      end

      it 'rejects @example.com email addresses' do
        Settings['contact_email'] = 'test@example.com'

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.to raise_error(RuntimeError, /cannot use example domain/)
      end

      it 'rejects @example.org email addresses' do
        Settings['contact_email'] = 'test@example.org'

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.to raise_error(RuntimeError, /cannot use example domain/)
      end

      it 'rejects invalid email format' do
        Settings['contact_email'] = 'not-an-email'

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.to raise_error(RuntimeError, /invalid format/)
      end

      it 'rejects email without domain' do
        Settings['contact_email'] = 'admin@'

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.to raise_error(RuntimeError, /invalid format/)
      end

      it 'requires SMTP address' do
        Settings['contact_email'] = 'admin@company.com'
        Settings.smtp.settings['address'] = nil

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.to raise_error(RuntimeError, /Required SMTP settings are missing/)
      end

      it 'requires SMTP port' do
        Settings['contact_email'] = 'admin@company.com'
        Settings.smtp.settings['address'] = 'smtp.company.com'
        Settings.smtp.settings['port'] = nil

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.to raise_error(RuntimeError, /Required SMTP settings are missing/)
      end

      it 'requires SMTP domain' do
        Settings['contact_email'] = 'admin@company.com'
        Settings.smtp.settings['address'] = 'smtp.company.com'
        Settings.smtp.settings['port'] = 587
        Settings.smtp.settings['domain'] = nil

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.to raise_error(RuntimeError, /Required SMTP settings are missing/)
      end

      it 'accepts valid SMTP configuration' do
        Settings['contact_email'] = 'admin@company.com'
        Settings.smtp.settings['address'] = 'smtp.company.com'
        Settings.smtp.settings['port'] = 587
        Settings.smtp.settings['domain'] = 'company.com'

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.not_to raise_error
      end

      it 'warns when password is missing' do
        Settings['contact_email'] = 'admin@company.com'
        Settings.smtp.settings['address'] = 'smtp.company.com'
        Settings.smtp.settings['port'] = 587
        Settings.smtp.settings['domain'] = 'company.com'
        Settings.smtp.settings['password'] = nil

        expect(Rails.logger).to receive(:warn).with(/VULCAN_SMTP_SERVER_PASSWORD is not set/)

        load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
      end
    end

    context 'when SMTP is disabled in production' do
      before do
        Settings.smtp['enabled'] = false
        stub_const('Rails::Server', Class.new)
      end

      it 'does not require contact_email' do
        Settings['contact_email'] = nil

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.not_to raise_error
      end

      it 'allows example.com email when SMTP disabled' do
        Settings['contact_email'] = 'test@example.com'

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.not_to raise_error

        # But it should set to nil
        expect(Settings['contact_email']).to be_nil
      end
    end

    context 'in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        Settings.smtp['enabled'] = true
      end

      it 'uses fallback email for contact_email' do
        Settings['contact_email'] = nil

        load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')

        expect(Settings['contact_email']).to eq('vulcan-support@example.com')
      end

      it 'allows example.com in development' do
        Settings['contact_email'] = 'dev@example.com'

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.not_to raise_error

        expect(Settings['contact_email']).to eq('dev@example.com')
      end
    end

    context 'during rake tasks in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        Settings.smtp['enabled'] = true
        # Rails::Server not defined during rake tasks
        hide_const('Rails::Server')
      end

      it 'does not validate SMTP settings' do
        Settings['contact_email'] = 'test@example.com'
        Settings.smtp.settings['address'] = nil

        expect do
          load Rails.root.join('config', 'initializers', '0_settings.rb', '0_settings.rb')
        end.not_to raise_error

        # But should set example.com to nil
        expect(Settings['contact_email']).to be_nil
      end
    end
  end
end
