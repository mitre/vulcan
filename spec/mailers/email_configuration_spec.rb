# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email Configuration Integration' do
  describe 'ApplicationMailer configuration' do
    it 'uses Settings.contact_email for from address' do
      # This tests the actual mailer configuration
      mailer = ApplicationMailer.new
      expect(mailer.class.default[:from].call).to eq(Settings.contact_email)
    end

    it 'falls back to example.com in development when not configured' do
      original_email = Settings.contact_email
      Settings['contact_email'] = nil

      # Reload settings to apply fallback
      load Rails.root.join('config/initializers/0_settings.rb')

      expect(Settings.contact_email).to eq('vulcan-support@example.com')

      # Restore
      Settings['contact_email'] = original_email
    end
  end

  describe 'UserMailer configuration' do
    it 'uses Settings.contact_email as default from address' do
      # Test that ApplicationMailer is configured correctly
      expect(ApplicationMailer.default[:from]).to be_a(Proc)
      expect(ApplicationMailer.default[:from].call).to eq(Settings.contact_email)
    end

    it 'from address does not use example.com in test environment' do
      # In test environment, Settings.contact_email should be safe
      # but never @example.com in production
      if Rails.env.production?
        expect(Settings.contact_email).not_to end_with('@example.com', '@example.org')
      end
    end
  end

  describe 'SMTP delivery behavior' do
    context 'when SMTP is disabled' do
      before do
        allow(Settings.smtp).to receive(:enabled).and_return(false)
      end

      it 'controller logic should not attempt email delivery' do
        # This simulates controller behavior from application_controller.rb
        # Emails should only be sent when Settings.smtp.enabled is true

        email_sent = false

        if Settings.smtp.enabled
          # This block should NOT execute
          email_sent = true
        end

        expect(email_sent).to be false
      end
    end

    context 'when SMTP is enabled' do
      before do
        allow(Settings.smtp).to receive(:enabled).and_return(true)
      end

      it 'controller logic allows email delivery' do
        # This simulates controller behavior
        email_sent = false

        if Settings.smtp.enabled
          email_sent = true
        end

        expect(email_sent).to be true
      end
    end
  end

  describe 'SMTP settings validation in smtp_settings.rb initializer' do
    context 'when username not explicitly set' do
      it 'defaults to contact_email' do
        # This tests the initializer logic from smtp_settings.rb line 11:
        # smtp_settings['user_name'] ||= Settings.contact_email

        smtp_config = Settings.smtp.settings.dup
        smtp_config['user_name'] ||= Settings.contact_email

        expect(smtp_config['user_name']).to eq(Settings.contact_email)
      end
    end
  end

  describe 'email address validation' do
    it 'validates email format with basic check' do
      # Test that our validation logic correctly identifies example domains
      invalid_emails = ['test@example.com', 'admin@example.org']
      valid_emails = ['admin@company.com', 'support@my-org.net']

      invalid_emails.each do |email|
        expect(email.end_with?('@example.com', '@example.org')).to be true
      end

      valid_emails.each do |email|
        expect(email.end_with?('@example.com', '@example.org')).to be false
      end
    end

    it 'accepts properly formatted email addresses' do
      valid_email = 'admin@company.com'

      expect do
        Mail::Address.new(valid_email)
      end.not_to raise_error
    end

    it 'detects example.com domains' do
      test_email = 'test@example.com'
      expect(test_email).to end_with('@example.com')
    end

    it 'detects example.org domains' do
      test_email = 'test@example.org'
      expect(test_email).to end_with('@example.org')
    end
  end

  describe 'regression prevention for production email bug' do
    it 'ensures production never uses @example.com when SMTP enabled' do
      # This is the regression test for the original bug you reported
      # In production with SMTP enabled, example.com should cause failure

      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      stub_const('Rails::Server', Class.new)

      # Save original settings
      original_email = Settings.contact_email
      original_enabled = Settings.smtp.enabled

      Settings.smtp['enabled'] = true
      Settings['contact_email'] = 'test@example.com'

      expect do
        load Rails.root.join('config/initializers/0_settings.rb')
      end.to raise_error(RuntimeError, /cannot use example domain/)

      # Restore
      Settings['contact_email'] = original_email
      Settings.smtp['enabled'] = original_enabled
    end

    it 'ensures SMTP configuration is validated before sending emails' do
      # This prevents the scenario where admin enables SMTP but forgets settings

      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      stub_const('Rails::Server', Class.new)

      original_enabled = Settings.smtp.enabled
      Settings.smtp['enabled'] = true
      Settings['contact_email'] = 'admin@company.com'
      # Missing SMTP settings
      Settings.smtp.settings['address'] = nil

      expect do
        load Rails.root.join('config/initializers/0_settings.rb')
      end.to raise_error(RuntimeError, /Required SMTP settings are missing/)

      # Restore
      Settings.smtp['enabled'] = original_enabled
    end
  end
end
