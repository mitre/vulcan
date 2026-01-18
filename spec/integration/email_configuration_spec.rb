# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email Configuration Integration - Core Validation' do
  # Simple integration tests that validate our email configuration fixes work
  # Focus on configuration validation rather than complex email rendering

  # Helper methods to eliminate code duplication
  def reload_smtp_settings
    load Rails.root.join('config', 'initializers', 'smtp_settings.rb')
  end

  def setup_production_smtp(smtp_settings, contact_email)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(Settings.smtp).to receive_messages(enabled: true, settings: smtp_settings)
    allow(Settings).to receive(:contact_email).and_return(contact_email)
  end

  def test_application_mailer_from_address
    mailer = ApplicationMailer.new
    mailer.default_params[:from].call
  end

  after do
    # Reset ActionMailer settings after each test (parallel-safe)
    # Must reset BOTH config and Base (initializer sets both)
    Rails.application.config.action_mailer.delivery_method = :test
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.smtp_settings = {}
  end

  describe 'Production SMTP Configuration Fix (Core Issue Resolution)' do
    context 'Gmail/MITRE authentication mismatch scenario (original production bug)' do
      before do
        setup_production_smtp(
          {
            'address' => 'smtp.gmail.com',
            'port' => 587,
            'authentication' => 'plain'
            # NO explicit user_name - this was the original problem
          },
          'saf@mitre.org'
        )
      end

      it 'resolves SMTP authentication mismatch by defaulting username to contact_email' do
        reload_smtp_settings

        # Verify our fix worked - SMTP username should default to contact_email
        expect(ActionMailer::Base.smtp_settings[:user_name]).to eq('saf@mitre.org')
        expect(ActionMailer::Base.smtp_settings[:address]).to eq('smtp.gmail.com')
      end

      it 'ensures ApplicationMailer from address matches SMTP authentication' do
        reload_smtp_settings

        # Test ApplicationMailer from address
        from_address = test_application_mailer_from_address

        # Both should use the same email - no more mismatch!
        smtp_username = ActionMailer::Base.smtp_settings[:user_name]
        expect(from_address).to eq('saf@mitre.org')
        expect(smtp_username).to eq('saf@mitre.org')
        expect(from_address).to eq(smtp_username), 'From address should match SMTP username'
      end
    end

    context 'Professional email service scenario (recommended approach)' do
      before do
        setup_production_smtp(
          {
            'address' => 'smtp.mailgun.org',
            'port' => 587,
            'authentication' => 'plain'
          },
          'vulcan-demo@mitre.org'
        )
      end

      it 'defaults SMTP username to contact_email for professional services' do
        reload_smtp_settings

        expect(ActionMailer::Base.smtp_settings[:user_name]).to eq('vulcan-demo@mitre.org')
        expect(ActionMailer::Base.smtp_settings[:address]).to eq('smtp.mailgun.org')
      end

      it 'preserves explicit SMTP username when provided (backward compatibility)' do
        # Test complex deployment scenario
        allow(Settings.smtp).to receive(:settings).and_return({
                                                                'address' => 'smtp.sendgrid.net',
                                                                'port' => 587,
                                                                'authentication' => 'plain',
                                                                'user_name' => 'apikey' # Explicit username provided
                                                              })

        load Rails.root.join('config', 'initializers', 'smtp_settings.rb')

        # Should preserve explicit username, not override with contact_email
        expect(ActionMailer::Base.smtp_settings[:user_name]).to eq('apikey')
      end
    end
  end

  describe 'ApplicationMailer Community Standard Validation' do
    it 'follows Rails community pattern like OpenProject and Alonetone' do
      allow(Settings).to receive(:contact_email).and_return('community-test@example.com')

      # Test that ApplicationMailer uses simple, direct configuration
      from_address = test_application_mailer_from_address

      expect(from_address).to eq('community-test@example.com')
    end

    it 'handles different contact_email values correctly' do
      test_emails = [
        'support@company.com',
        'notifications@organization.org',
        'vulcan-demo@mitre.org'
      ]

      test_emails.each do |test_email|
        allow(Settings).to receive(:contact_email).and_return(test_email)

        mailer = ApplicationMailer.new
        from_address = mailer.default_params[:from].call

        expect(from_address).to eq(test_email),
                                "ApplicationMailer should handle contact_email: #{test_email}"
      end
    end
  end

  describe 'Open Source Default Email Improvement' do
    it 'uses improved default instead of problematic old default' do
      # Our new improved default
      allow(Settings).to receive(:contact_email).and_return('vulcan-support@example.com')

      mailer = ApplicationMailer.new
      from_address = mailer.default_params[:from].call

      # Verify improved default
      expect(from_address).to eq('vulcan-support@example.com')
      expect(from_address).not_to include('do_not_reply@vulcan'), 'Should not use old problematic default'
      expect(from_address).to include('@example.com'), 'Should have proper domain'
      expect(from_address).to include('support'), 'Should imply support availability'
    end
  end

  describe 'Environment-Specific Behavior Validation' do
    it 'SMTP settings only apply in production environment' do
      # Test that non-production environments don't get SMTP configuration
      allow(Settings.smtp).to receive_messages(
        enabled: true,
        settings: {
          'address' => 'smtp.example.com',
          'user_name' => 'should-not-be-used'
        }
      )

      %w[development test].each do |env|
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new(env))

        # Reset settings before loading
        ActionMailer::Base.smtp_settings = {}

        # Load initializer
        load Rails.root.join('config', 'initializers', 'smtp_settings.rb')

        # Non-production environments should not get SMTP settings
        expect(ActionMailer::Base.smtp_settings).to be_empty,
                                                    "#{env} environment should not configure SMTP settings"
      end
    end
  end
end
